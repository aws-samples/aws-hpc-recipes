#!/usr/bin/env bash

# Usage: pcs_bootstrap_finalize.sh /etc/amazon/pcs/bootstrap_config.json
#
# This is the last script called by PCS automated bootstrapping. It enables and launches 
# the Slurm service, then checks that it is running. It assumes the presence of a Slurmd 
# service file in /etc/systemd/system/slurmd.service. 

BOOTSTRAP_CONFIG_FILE=$1
REGISTER_NODE_GROUP_INSTANCE_FILE="/etc/amazon/pcs/register_node_group_instance.json"

# Load commomn functions
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

# Enable service, start it, then check its status with sinfo
retry_command "systemctl enable slurmd" 2
# These retries can take around 1 minute each
retry_command "systemctl start slurmd" 2
# We let Slurmd take its time to start up
retry_command "/opt/slurm/bin/sinfo" 6

completed
