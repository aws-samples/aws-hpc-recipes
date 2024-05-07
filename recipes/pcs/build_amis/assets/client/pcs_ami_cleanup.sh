#!/usr/bin/env bash

# Usage: pcs_ami_cleanup.sh /etc/amazon/pcs/bootstrap_config.json
#
# Cleans up material that should not be in a PCS node group AMI

BOOTSTRAP_CONFIG_FILE=$1

# Load commomn functions
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

for F in /etc/amazon/pcs/register_node_group_instance.json /opt/slurm/etc/slurm.key /var/log/amazon/pcs/bootstrap.log /etc/sysconfig/slurmd /var/log/pcs_bootstrap_init.*.log
do
    rm -rf $F
done

completed
