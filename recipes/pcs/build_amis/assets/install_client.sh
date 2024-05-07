#!/bin/bash

# Install PCS client scripts + dependencies on Rocky8, Rocky9

# Set up PCS managed directories
for D in /opt/aws/pcs/bin /etc/amazon/pcs/
do
    mkdir -p $D && chmod 600 $D
done

# Set up dependencies for PCS client scripts
dnf install -y python3 jq curl
/usr/bin/python3 -m venv /root/pcs
/root/pcs/bin/python -m pip install awscurl==0.33 botocore==1.26.10

# Install client scripts from S3
URL_BASE="https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/pcs/recipes/pcs/build_amis/assets/client"
for SCRIPT in common.sh pcs_ami_cleanup.sh pcs_bootstrap_config_always.sh pcs_bootstrap_config_per_instance.sh pcs_bootstrap_finalize.sh pcs_bootstrap_init.sh
do
    curl -skL -O ${URL_BASE}/${SCRIPT} && mv ${SCRIPT} /opt/aws/pcs/bin && chmod 0755 /opt/aws/pcs/bin/${SCRIPT}
done

# Check for other dependencies

