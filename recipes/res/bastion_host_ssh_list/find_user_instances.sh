#!/bin/bash

# Script to find EC2 instances with Name tags containing the SSH username
# and display their private IPs in a table format

# Get the SSH username from the SSH_CLIENT or SSH_CONNECTION environment variable
# If not available (e.g., when running locally), use the current user
if [[ -n "$SSH_CLIENT" || -n "$SSH_CONNECTION" ]]; then
    # Get the username from the SSH session
    SSH_USER=$(who am i | awk '{print $1}')
else
    # Fallback to current user if not in SSH session
    SSH_USER=$(whoami)
    echo "Not in SSH session, using current user: $SSH_USER"
fi

echo "Looking for EC2 instances with names containing: $SSH_USER"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if jq is installed (for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install it first."
    exit 1
fi

# Get all running EC2 instances
echo "Querying EC2 instances..."
INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].{InstanceId:InstanceId,PrivateIP:PrivateIpAddress,Name:Tags[?Key=='Name'].Value|[0]}" \
    --output json)

# Check if the AWS CLI command was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to query EC2 instances. Check your AWS credentials and permissions."
    exit 1
fi

# Filter instances where Name tag contains the SSH username and create a table
MATCHING_INSTANCES=$(echo "$INSTANCES" | jq -r '.[] | .[] | select(.Name != null) | select(.Name | ascii_downcase | contains("'"$(echo $SSH_USER | tr '[:upper:]' '[:lower:]')"'")) | "\(.InstanceId)\t\(.Name)\t\(.PrivateIP)"')

# Check if any matching instances were found
if [ -z "$MATCHING_INSTANCES" ]; then
    echo "No EC2 instances found with names containing '$SSH_USER'"
    exit 0
fi

# Print the table header
printf "%-20s %-40s %-15s\n" "INSTANCE ID" "NAME" "PRIVATE IP"
printf "%-20s %-40s %-15s\n" "----------" "----" "----------"

# Print the table content
echo "$MATCHING_INSTANCES" | while IFS=$'\t' read -r id name ip; do
    printf "%-20s %-40s %-15s\n" "$id" "$name" "$ip"
done

echo ""
echo "Found $(echo "$MATCHING_INSTANCES" | wc -l | tr -d ' ') instance(s) matching '$SSH_USER'"
