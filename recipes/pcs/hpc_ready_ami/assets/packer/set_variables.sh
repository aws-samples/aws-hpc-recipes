#!/bin/bash

# Usage: set_variables.sh DISTRO ARCHITECTURE
#
# Example: set_variables.sh ubuntu_22_04 x86_64

# Set default values
SSH_USERNAME="ec2-user"
ROOT_DEVICE_NAME="/dev/sda1"
INSTANCE_TYPE="c6a.8xlarge"
DISTRO="amzn_2"

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
DISTRO=$1

case "$2" in
    x86_64*)
        INSTANCE_TYPE="c6a.8xlarge"
        ;;
    arm64*)
        INSTANCE_TYPE="c7g.8xlarge"
        ;;
    *)
        echo "Unknown architecture: $2" >&2
        exit 1
        ;;
esac
ARCHITECTURE=$2

# Output the values in a format Packer can use
echo "{"
echo "  \"ssh_username\": \"$SSH_USERNAME\","
echo "  \"distribution\": \"$DISTRO\","
echo "  \"architecture\": \"$ARCHITECTURE\","
echo "  \"instance_type\": \"$INSTANCE_TYPE\","
echo "  \"root_device_name\": \"$ROOT_DEVICE_NAME\""
echo "}"
