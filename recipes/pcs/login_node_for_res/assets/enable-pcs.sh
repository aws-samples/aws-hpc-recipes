#!/bin/bash

set -euo pipefail

cluster_id=${1:-$CLUSTER_ID}
region=${2:-$AWS_REGION}

function help() {
  cat <<EOF

  Usage: $0 <CLUSTER_ID> <AWS_REGION>

  Arguments:
    - CLUSTER_ID:                   PCS Cluster ID (e.g. pcs_wgs83921a)
    - AWS_REGION:                   AWS region to use (e.g. us-east-1).  

  Environment Variables:
    CLUSTER_ID                    PCS Cluster ID
    AWS_REGION                    AWS Region
EOF
}

# Fail if region or cluster_id is not provided
if [ -z "$region" ] || [ -z "$cluster_id" ]; then
    echo "ERROR: Missing 'AWS_REGION' or 'CLUSTER_ID'"
    help
    exit 1
fi

DEFAULT_SLURM_VERSION="24.05.5-2"
slurm_version=${SLURM_VERSION:-$DEFAULT_SLURM_VERSION}
slurm_major_minor=$(echo $slurm_version | cut -d. -f1,2)

# Create IAM Policy
cat > /tmp/slurm-compute-iam-policy.json << EOF
  RESPCSPolicy:
    Type: AWS::IAM::ManagedPolicy
    Properties:
      PolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Action:
              - pcs:getCluster
            Resource: !Sub "arn:${AWS::Partition}:pcs:${AWS::Region}:${AWS::AccountId}:cluster/${PCSClusterId}"
          - Effect: Allow
            Action:
              - secretsmanager:getSecretValue
            Resource: !Sub "arn:${AWS::Partition}:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:pcs!*"
EOF

# Update system
yum update -y

# Check what version of awscli is installed
awscli_version=$(aws --version | cut -d/ -f2 | cut -d. -f1)
if [ "$awscli_version" -lt 2 ]; then
  echo "Updating awscli to v2"

  # Remove pre-installed aws cli
  yum remove awscli -yq

  # Install AWS CLI
  echo "Installing AWS CLI"
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update

  # Update path to use awscli v2
  export PATH=/usr/local/bin:$PATH
fi

# Get cluster details
slurm_ip=$(aws pcs get-cluster --region $region --cluster-identifier $cluster_id --query "cluster.endpoints[0].privateIpAddress")
slurm_port=$(aws pcs get-cluster --region $region --cluster-identifier $cluster_id --query "cluster.endpoints[0].port")
slurm_key_arn=$(aws pcs get-cluster --region $region --cluster-identifier $cluster_id --query "cluster.slurmConfiguration.authKey.secretArn")

#strip the double-quote 
slurm_ip=$(echo $slurm_ip | tr -d '"')
slurm_port=$(echo $slurm_port | tr -d '"')
slurm_key_arn=$(echo $slurm_key_arn | tr -d '"')

mkdir -p /etc/slurm

aws secretsmanager get-secret-value \
    --region $region \
    --secret-id $slurm_key_arn \
    --version-stage AWSCURRENT \
    --query 'SecretString' \
    --output text | base64 -d > /etc/slurm/slurm.key

#install slurm
curl https://aws-pcs-repo-${region}.s3.amazonaws.com/aws-pcs-slurm/aws-pcs-slurm-${slurm_major_minor}-installer-${slurm_version}.tar.gz \
    -o aws-pcs-slurm-${slurm_major_minor}-installer-${slurm_version}.tar.gz

tar -xf aws-pcs-slurm-${slurm_major_minor}-installer-${slurm_version}.tar.gz && \
    rm aws-pcs-slurm-${slurm_major_minor}-installer-${slurm_version}.tar.gz
    cd aws-pcs-slurm-${slurm_major_minor}-installer

echo "Installing aws-pcs-slurm"
./installer.sh -y
cd ..
rm -rf aws-pcs-slurm-${slurm_major_minor}-installer

# run this after slurm is installed so "slurm" user exists. 
chmod 0600 /etc/slurm/slurm.key
chown slurm:slurm /etc/slurm/slurm.key

#install pcs agent
DEFAULT_AGENT_VERSION="1.1.1-1"
agent_version=${PCS_AGENT_VERSION:-$DEFAULT_AGENT_VERSION}
curl https://aws-pcs-repo-${region}.s3.amazonaws.com/aws-pcs-agent/aws-pcs-agent-v${agent_version}.tar.gz -o aws-pcs-agent-v${agent_version}.tar.gz

tar -xf aws-pcs-agent-v${agent_version}.tar.gz && \
    rm aws-pcs-agent-v${agent_version}.tar.gz
    cd aws-pcs-agent

echo "Installing aws-pcs-agent"
./installer.sh
cd ..
rm -rf aws-pcs-agent

echo "SACKD_OPTIONS='--conf-server=${slurm_ip}:${slurm_port}'" > /etc/sysconfig/sackd

sudo cat << EOF > /etc/systemd/system/sackd.service
[Unit]
Description=Slurm auth and cred kiosk daemon
After=network-online.target remote-fs.target
Wants=network-online.target
ConditionPathExists=/etc/sysconfig/sackd

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/sackd
User=slurm
Group=slurm
RuntimeDirectory=slurm
RuntimeDirectoryMode=0755
ExecStart=/opt/aws/pcs/scheduler/slurm-${slurm_major_minor}/sbin/sackd --systemd \$SACKD_OPTIONS
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
LimitNOFILE=131072
LimitMEMLOCK=infinity
LimitSTACK=infinity

[Install]
WantedBy=multi-user.target
EOF

sudo chown root:root /etc/systemd/system/sackd.service && \
    sudo chmod 0644 /etc/systemd/system/sackd.service

sudo systemctl daemon-reload && sudo systemctl enable sackd
sudo systemctl start sackd

echo "PATH=\$PATH:/opt/aws/pcs/scheduler/slurm-${slurm_major_minor}/bin/" >> /etc/bashrc
