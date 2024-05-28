#!/usr/bin/bash

# Prepare a Rocky 8.9 AMI that can work with AWS Parallel Computing Service
#
# Presented as a single script, but it is recommended you run each major step interactively.

# Update system packages
dnf -y update

# Install AWSCLIv2
dnf install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install SSM Agent
# https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-rocky.html
sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent

# Python3 virtualenv and jq (for PCS client)
dnf install -y python3 jq curl
/usr/bin/python3 -m venv /root/pcs
/root/pcs/bin/python -m pip install awscurl==0.33 botocore==1.26.10

# Install PCS beta client
# Set up PCS managed directories
for D in /opt/aws/pcs/bin /etc/amazon/pcs/
do
    mkdir -p $D && chmod 600 $D
done
# Install scripts from S3
# TODO - make this a zipped tarball in 
URL_BASE="https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/pcs/recipes/pcs/build_amis/assets/client"
for SCRIPT in common.sh pcs_ami_cleanup.sh pcs_bootstrap_config_always.sh pcs_bootstrap_config_per_instance.sh pcs_bootstrap_finalize.sh pcs_bootstrap_init.sh
do
    curl -skL -O ${URL_BASE}/${SCRIPT} && mv ${SCRIPT} /opt/aws/pcs/bin && chmod 0755 /opt/aws/pcs/bin/${SCRIPT}
done

# User management
# For beta, Slurm uid must be 401 or there will be constant auth errors in the log
useradd --uid 400 --home-dir /home/pcs-admin --shell /bin/bash --comment "pcs admin user" -U --system --create-home pcs-admin
useradd --uid 401 --home-dir /home/slurm --shell /bin/bash --comment "slurm user" -U --system --create-home slurm
groupadd --gid 405 --system pcs-slurm-share
usermod --append --groups pcs-slurm-share pcs-admin
usermod --append --groups pcs-slurm-share slurm

# Third-party software required for PCS
# Dependencies for Slurm, etc
# Enable powertools repo
dnf install -y dnf-plugins-core
dnf config-manager --set-enabled powertools
dnf install -y autoconf automake bind-utils bzip2 coreutils curl environment-modules gcc gcc-c++ git http-parser-devel hwloc hwloc-devel jansson-devel jq json-c-devel kernel-devel ksh libcurl-devel libevent-devel libgcrypt-devel libtool libxml2-devel lua-devel ncurses-devel net-tools openmotif-devel openssl-devel pam-devel perl-Switch redhat-lsb sendmail tcl-devel tcsh vim yum-plugin-versionlock zsh

mkdir -p /root/third-party-software

# JWT
cd /root/third-party-software
jwt_version="1.15.3"
curl -skL -O https://github.com/benmcollins/libjwt/archive/refs/tags/v${jwt_version}.tar.gz
tar xf v${jwt_version}.tar.gz --no-same-owner
cd libjwt-${jwt_version}
 # Needs autotools
autoreconf --force --install
./configure --prefix=/opt/libjwt
CORES=$(grep processor /proc/cpuinfo | wc -l)
make -j $CORES
make install

# PMIX
cd /root/third-party-software
pmix_version="4.2.7"
curl -skL -O https://github.com/openpmix/openpmix/releases/download/v4.2.7/pmix-${pmix_version}.tar.gz
tar xf pmix-${pmix_version}.tar.gz --no-same-owner
cd pmix-${pmix_version}
./configure --prefix=/opt/pmix
CORES=$(grep processor /proc/cpuinfo | wc -l)
make -j $CORES
make install

# Set LD path for PMIX
echo "/opt/pmix/lib" > /etc/ld.so.conf.d/pmix.conf && chown root:root /etc/ld.so.conf.d/pmix.conf && chmod 0644 /etc/ld.so.conf.d/pmix.conf

# Slurm
cd /root/third-party-software
slurm_version="23.11.7"
curl -skL -O https://download.schedmd.com/slurm/slurm-${slurm_version}.tar.bz2
tar xjf slurm-${slurm_version}.tar.bz2 --no-same-owner
cd slurm-${slurm_version}
source /root/pcs/bin/activate
./configure --prefix=/opt/slurm --with-pmix=/opt/pmix --with-jwt=/opt/libjwt --without-munge
CORES=$(grep processor /proc/cpuinfo | wc -l)
make -j $CORES
make install
make install-contrib
deactivate

# Set LD path for Slurm
if [ ! -f /etc/ld.so.conf.d/slurm.conf ];
then
  echo "/opt/slurm/lib/" > /etc/ld.so.conf.d/slurm.conf && chmod 0744 /etc/ld.so.conf.d/slurm.conf
fi

# Create Slurmd service file
cat <<EOF > /etc/systemd/system/slurmd.service
[Unit]
Description=Slurm node daemon
After=network-online.target remote-fs.target sssd.service
Wants=network-online.target
ConditionPathExists=/etc/sysconfig/slurmd

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/slurmd
RuntimeDirectory=slurm
RuntimeDirectoryMode=0755
ExecStart=/opt/slurm/sbin/slurmd --systemd \$SLURMD_OPTIONS
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
LimitNOFILE=131072
LimitMEMLOCK=infinity
LimitSTACK=infinity
Delegate=yes
TasksMax=infinity
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

# Set ownership and permissions
chown root:root /etc/systemd/system/slurmd.service && chmod 0644 /etc/systemd/system/slurmd.service

# Slurm etc directory (needed for job restarts)
mkdir -p /opt/slurm/etc && chown pcs-admin:pcs-admin /opt/slurm/etc && chmod 0755 /opt/slurm/etc

# Enable pcs-admin to manage Slurm
cat << EOF > /etc/sudoers.d/99-pcs-slurm
Cmnd_Alias SLURM_COMMANDS = /opt/slurm/bin/scontrol, /opt/slurm/bin/sinfo
Cmnd_Alias SHUTDOWN = /usr/sbin/shutdown
pcs-admin ALL = (root) NOPASSWD: SLURM_COMMANDS
pcs-admin ALL = (root) NOPASSWD: SHUTDOWN
EOF
chown root:root /etc/sudoers.d/99-pcs-slurm
chmod 0600  /etc/sudoers.d/99-pcs-slurm

# Create and symlink Slurm shell profiles
cat <<EOF > /opt/slurm/etc/slurm.sh
#
# slurm.sh:
#   Setup slurm environment variables
#

PATH=$PATH:/opt/slurm/bin
MANPATH=$MANPATH:/opt/slurm/share/man

export PATH MANPATH
EOF
chown root:root /opt/slurm/etc/slurm.sh
chmod 0755 /opt/slurm/etc/slurm.sh
ln -s /opt/slurm/etc/slurm.sh /etc/profile.d/slurm.sh

cat <<EOF > /opt/slurm/etc/slurm.csh
#
# slurm.csh:
#     Sets the C shell user environment for slurm commands
#
set path = (\$path /opt/slurm/bin)
if ( \${?MANPATH} ) then
  setenv MANPATH \${MANPATH}:/opt/slurm/share/man
else
  setenv MANPATH :/opt/slurm/share/man
endif
EOF
chown root:root /opt/slurm/etc/slurm.csh
chmod 0755 /opt/slurm/etc/slurm.csh
ln -s /opt/slurm/etc/slurm.csh /etc/profile.d/slurm.csh


# Now, feel free to install other software, like Lustre.

