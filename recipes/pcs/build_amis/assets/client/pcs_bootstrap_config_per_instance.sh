#!/usr/bin/env bash

# Usage: pcs_bootstrap_per_instance.sh /etc/amazon/pcs/bootstrap_config.json
#
# This is the third script called by PCS automated bootstrapping. It writes the Slurm key file 
# and the sysconfig file for Slurm. It assumes that /etc/amazon/pcs/register_node_group_instance.json 
# has already been written a previous script. It also assumes there is an /opt/slurm directory 
# present and a user/group named 'slurm'.

BOOTSTRAP_CONFIG_FILE=$1
REGISTER_NODE_GROUP_INSTANCE_FILE="/etc/amazon/pcs/register_node_group_instance.json"
SLURM_USER="slurm"
SLURM_GROUP="slurm"
SLURM_KEY_FILE="/opt/slurm/etc/slurm.key"
SLURMD_SYSCONFIG_FILE="/etc/sysconfig/slurmd"

# Load commomn functions
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

# Load REGISTER_NODE_GROUP_INSTANCE_FILE
registration_file_data=$(cat $REGISTER_NODE_GROUP_INSTANCE_FILE | jq -r .)

# Decode sharedSecret into a Slurm key file
if [ ! -f "${SLURM_KEY_FILE}" ];
then
    shared_secret=$(get_json_attr "${registration_file_data}" ".RegisterComputeNodeGroupInstance.sharedSecret")
    debug "${shared_secret}"
    base64 --decode <<< "${shared_secret}" > ${SLURM_KEY_FILE} && chown ${SLURM_USER}:${SLURM_GROUP} ${SLURM_KEY_FILE} && chmod 600 ${SLURM_KEY_FILE}
else
    warn "Slurm key already exists at ${SLURM_KEY_FILE}. Delete to run this function again."
fi

# Prepare /etc/sysconfig
mkdir -p /etc/sysconfig && chown root:root /etc/sysconfig && chmod 0644 /etc/sysconfig

# Write out Slurmd sysconfig
if [ ! -f "${SLURMD_SYSCONFIG_FILE}" ];
then
    # Example output: SLURMD_OPTIONS='-c --conf-server=10.3.136.86:6817 -N default-1 --instance-id i-059c165d80c4fdf9c --instance-type c6i.xlarge'
    instance_id=$(get_ec2_instance_id)
    instance_type=$(get_ec2_instance_type)
    node_id=$(get_json_attr "${registration_file_data}" ".RegisterComputeNodeGroupInstance.nodeId")
    endpoints=$(get_json_attr "${registration_file_data}" ".RegisterComputeNodeGroupInstance.endpoints")
    echo "SLURMD_OPTIONS='-c --conf-server=${endpoints} -N ${node_id} --instance-id ${instance_id} --instance-type ${instance_type}'" > ${SLURMD_SYSCONFIG_FILE} && chown root:root ${SLURMD_SYSCONFIG_FILE} && chmod 0644 ${SLURMD_SYSCONFIG_FILE}
else
    warn "Slurmd sysconfig already exists at ${SLURMD_SYSCONFIG_FILE}. Delete to run this function again."
fi

completed

