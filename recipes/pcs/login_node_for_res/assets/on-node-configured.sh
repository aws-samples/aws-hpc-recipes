#!/bin/bash

set -euo pipefail

DEFAULT_SLURM_VERSION="23.11.9-1"

region=${AWS_REGION}
cluster_id=${CLUSTER_ID}
slurm_version=${SLURM_VERSION:-$DEFAULT_SLURM_VERSION}
slurm_major_minor=$(echo $slurm_version | cut -d. -f1,2)

# Fail if region or cluster_id is not provided
if [ -z "$region" ] || [ -z "$cluster_id" ]; then
    echo "ERROR: Missing 'AWS_REGION' or 'CLUSTER_ID'"
    exit 1
fi

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
slrum_port=$(echo $slurm_port | tr -d '"')
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
curl https://aws-pcs-repo-${region}.s3.amazonaws.com/aws-pcs-agent/aws-pcs-agent-v1.0.0-1.tar.gz -o aws-pcs-agent-v1.0.0-1.tar.gz

tar -xf aws-pcs-agent-v1.0.0-1.tar.gz && \
    rm aws-pcs-agent-v1.0.0-1.tar.gz
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
