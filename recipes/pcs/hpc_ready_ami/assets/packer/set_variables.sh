#!/bin/bash

# Set default values
SSH_USERNAME="ec2-user"
ROOT_DEVICE_NAME="/dev/sda1"

# Determine the correct values based on the distribution
case "$1" in
    amzn_2*)
        SSH_USERNAME="ec2-user"
        ROOT_DEVICE_NAME="/dev/xvda"
        ;;
    ubuntu_22_04*)
        SSH_USERNAME="ubuntu"
        ;;
    rocky_9*)
        SSH_USERNAME="rocky"
        ;;
    rhel_9*)
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
echo "  \"distribution\": \"$1\","
echo "  \"root_device_name\": \"$ROOT_DEVICE_NAME\""
echo "}"
