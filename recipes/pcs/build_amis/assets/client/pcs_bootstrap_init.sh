#!/usr/bin/env bash

# Usage: pcs_bootstrap_init.sh /etc/amazon/pcs/bootstrap_config.json
#
# Registers the node with PCS. This is the first script called by PCS automated bootstrapping. 
# Writes /etc/amazon/pcs/register_node_group_instance.json and log files at /var/log/pcs_bootstrap_init.*.log

BOOTSTRAP_CONFIG_FILE=$1
REGISTER_NODE_GROUP_INSTANCE_FILE="/etc/amazon/pcs/register_node_group_instance.json"

# Load commomn functions
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$DIR/common.sh"

function RegisterNodeGroupInstance() {

    cluster_id=$1
    cluster_name=$2
    local region=$3
    local timeout_seconds=$4
    local random_string=$(generate_random_hex)

    local node_manager_endpoint=$(get_json_attr "${BOOTSTRAP_CONFIG_FILE_DATA}" ".cluster.slurm.endpoint")
    local node_manager_service="pcs"
    local node_manager_target="com.amazon.aws.pcs.service.AWSParallelComputingService.RegisterComputeNodeGroupInstance"
    local node_manager_payload="{\"clusterIdentifier\": \"${cluster_id}\", \"bootstrapId\": \"${random_string}\"}"

    local node_register_command="/root/pcs/bin/awscurl -ki ${node_manager_endpoint} --service ${node_manager_service} --region ${region} -H 'Content-Encoding: amz-1.0' -H 'Content-Type: application/json; charset=UTF-8' -H 'Accept: application/json, text/javascript, */*' -H 'X-Amz-Target: ${node_manager_target}' -X POST -d '${node_manager_payload}'"
    debug "Command: ${node_register_command}"

    # Make API call with exponential backoff
    delay=2
    max_delay=64
    while true; do

        # Capture and log raw response
        raw_output=$(eval ${node_register_command})
        echo "${raw_output}" >> /var/log/pcs_bootstrap_init.1.log
        echo "--------" >> /var/log/pcs_bootstrap_init.1.log

        # Split the header from the body assuming double newline as the delimiter
        # NOTE: The redirect to dev/null catches "parse error: Invalid numeric literal at line 1, column 10 on STDERR"
        # Log the parsed JSON
        json_output=$(echo "${raw_output}" | sed "1,/^\s*$(printf '\r')*$/d" | jq . 2>/dev/null)
        echo "${json_output}" >> /var/log/pcs_bootstrap_init.2.log
        echo "--------" >> /var/log/pcs_bootstrap_init.2.log
        
        # Check for non-empty JSON output
        if [ "${json_output}" != "" ]; then
            # Check for an expected field. TODO: check for all of them
            # If we don't do this, any JSON response, including TimeOut, Throttling, and Auth errors will 
            # be interpreted as a successful registration. This is because error states are reported as 
            # JSON, same as success states.
            node_id=$(get_json_attr "${json_output}" ".nodeID")
            shared_secret=$(get_json_attr "${json_output}" ".sharedSecret")
            if [ "${node_id}" != "" ]; then
                break
            fi
        fi
        
        if [ $delay -gt $max_delay ]; then
            warn "Max delay reached, giving up"
            break
        fi
        
        delay=$((delay*2))
        sleep ${delay}
    done 

    echo "${json_output}"
}

BOOTSTRAP_CONFIG_FILE_DATA=$(cat ${BOOTSTRAP_CONFIG_FILE})

node_cluster_id=$(get_json_attr "${BOOTSTRAP_CONFIG_FILE_DATA}" ".cluster.cluster_id")
node_cluster_name="NA"
node_ec2_region=$(get_ec2_region) || "us-east-1"

node_group_manager_response=$(RegisterNodeGroupInstance ${node_cluster_id} ${node_cluster_name} ${node_ec2_region} 300)
# Log JSON response
echo "${node_group_manager_response}" >> /var/log/pcs_bootstrap_init.json_response.log
debug "${node_group_manager_response}"

node_id=$(get_json_attr "${node_group_manager_response}" ".nodeID")
shared_secret=$(get_json_attr "${node_group_manager_response}" ".sharedSecret")
# TODO - support >1 endpoint, differentiate SLURMCTLD from SLURMDBD endpoints
endpoint_ip=$(get_json_attr "${node_group_manager_response}" ".endpoints[0].privateIpAddress")
endpoint_port=$(get_json_attr "${node_group_manager_response}" ".endpoints[0].port")
endpoints="${endpoint_ip}:${endpoint_port}"

# Write out to destination file /etc/amazon/pcs/register_node_group_instance.json
registration_file_data="{\"RegisterComputeNodeGroupInstance\": {\"nodeId\": \"${node_id}\", \"endpoints\": \"${endpoints}\", \"sharedSecret\": \"${shared_secret}\"}}"
echo "${registration_file_data}" > ${REGISTER_NODE_GROUP_INSTANCE_FILE} && chmod 600 ${REGISTER_NODE_GROUP_INSTANCE_FILE}

completed
