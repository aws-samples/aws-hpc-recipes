#!/usr/bin/env bash

# Functions
function die() {
    echo "[ERROR] ${1}"
    exit 1
}

function warn() {
    echo "[WARNING] ${1}"
}

function info() {
    echo "[INFO] ${1}"
}

function debug() {
    echo "[DEBUG] ${1}" >&2
}

function completed() {
    info "Executed $(basename $0)"
    exit 0
}

function get_json_attr() {
    # Get attribute from JSON data by jq query
    local data=$1
    local attribute=$2
    local result=$(echo -n "${data}" | jq "${attribute}" -r)
    echo "${result}"
}

function get_imds_token() {
    local token=$(curl -X PUT -H "X-aws-ec2-metadata-token-ttl-seconds: 60" -H "Content-Type: application/x-amz-json-1.1" -sS http://169.254.169.254/latest/api/token)
    echo "${token}"
}

function get_ec2_region() {
    # Get EC2 region from instance metadata endpoint
    local token=$(get_imds_token)
    local region=$(curl -H "X-aws-ec2-metadata-token: $token" -sS http://169.254.169.254/latest/meta-data/placement/region)
    echo "$region"
}

function get_ec2_instance_id() {
    # Get instance ID from instance metadata endpoint
    local token=$(get_imds_token)
    local instance_id=$(curl -H "X-aws-ec2-metadata-token: $token" -sS http://169.254.169.254/latest/meta-data/instance-id)
    echo "$instance_id"
}

function get_ec2_instance_type() {
    # Get instance type from instance metadata endpoint
    local token=$(get_imds_token)
    local instance_type=$(curl -H "X-aws-ec2-metadata-token: $token" -sS http://169.254.169.254/latest/meta-data/instance-type)
    echo "$instance_type"
}

function retry_command() {
    # Simple polling function to run a command until it succeeds
    # TODO - add some jitter and/or progressive backoff
    local command=$1
    local max_attempts="${2:-10}"

    info "Running: $command (up to $max_attempts attempts)"
    local attempt=1

    while true; do
        # Run the command
        $command
        
        # Check the exit status
        if [ $? -eq 0 ]; then
            info "Command succeeded after $attempt attempts"
            break
        fi
        
        # Check if max attempts reached
        if [ $attempt -eq $max_attempts ]; then
            warn "Command failed after $max_attempts attempts"
            break
        fi
        
        warn "Command failed on attempt $attempt. Retrying in 2 seconds..."
        attempt=$((attempt+1))
        sleep 2
    done
}

generate_random_hex() {
    # Portable random hexadecimal generator
    local random_hex
    random_hex=$(LC_ALL=C tr -dc 'a-f0-9' < /dev/urandom | head -c 32)
    echo "$random_hex"
}

