#!/bin/bash

# Set default values
SSH_USERNAME="ec2-user"
ROOT_DEVICE_NAME="/dev/sda1"

# Determine the correct values based on the distribution
case "$1" in
    amzn*)
        SSH_USERNAME="ec2-user"
        ROOT_DEVICE_NAME="/dev/xvda"
        ;;
    ubuntu*)
        SSH_USERNAME="ubuntu"
        ;;
    rocky*)
        SSH_USERNAME="rocky"
        ;;
    rhel*)
        SSH_USERNAME="ec2-user"
        ;;
    *)
        echo "Invalid distro name: $1" >&2
        exit 1
        ;;
esac

# Output the values in a format Packer can use
echo "{"
echo "  \"ssh_username\": \"$SSH_USERNAME\","
echo "  \"root_device_name\": \"$ROOT_DEVICE_NAME\""
echo "}"
