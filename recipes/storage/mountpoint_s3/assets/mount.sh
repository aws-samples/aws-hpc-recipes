#!/bin/bash
set -e

# Usage: sudo bash mount.sh BUCKET_NAME DIRECTORY [OPTIONS]

# Override or extend these t change behavior of the mount
OPTIONS="--allow-root --read-only --debug"

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

# Determine operating system
function os_id() {
    if [[ $(uname -s) == "Linux" ]]; then
        OS_ID=$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }' | tr -d '"')
    elif [[ $(uname -s) == "Darwin" ]]; then
        OS_ID=darwin
    else
        OS_ID=unknown
    fi
    echo "${OS_ID}"
}

# Handle arguments

if [ "$#" -lt 2 ]; then
    die "Too few arguments"
fi

BUCKET_NAME=$1
DIRECTORY=$2
shift 2
# Options are passed to mount-s3. Concatenate them from an array into a single string.
PASSED_OPTIONS=$*

# Override default options if any are passed to the script.
# We are conservative here, making this a readonly mount.
# See user guide for details https://github.com/awslabs/mountpoint-s3/blob/main/doc/CONFIGURATION.md
if [[ "${PASSED_OPTIONS}" != "" ]]; then 
    OPTIONS="${PASSED_OPTIONS}"
fi

# Check dependencies

## Check host is using systemd
SYSINIT=$(ps -p 1 -o comm=)
if [[ "${SYSINIT}" != "systemd" ]]; then die "Host does appear to be using systemd."; fi

## Check mountpoint-s3 is installed 
command -v mount-s3 >/dev/null 2>&1 || { die "Mountpoint for Amazon S3 is not installed or accessible"; }

## If AWS CLI installed, validate S3 access to bucket
if command -v aws > /dev/null
then
    aws s3 ls "${BUCKET_NAME}" >/dev/null 2>&1 || { die "S3 bucket not found or accessible"; }
else
    warn "Cannot confirm access to S3 bucket. AWS CLI not installed."
fi

## Enforce existence of mount point
mkdir -p ${DIRECTORY} && chmod 777 ${DIRECTORY} || die "Unable to create or access mount point"

# Set default user/group
# NOTE: Not used right now
if [ "$(os_id)" == "ubuntu" ]; then
    POSIX_USER=ubuntu
    POSIX_GROUP=ubuntu
elif [ "$(os_id)" == "rocky" ]; then
    POSIX_USER=rocky
    POSIX_GROUP=rocky
else
    POSIX_USER=ec2-user
    POSIX_GROUP=ec2-user
fi

# Set systemd files destination
if [ "$(os_id)" == "rhel" ] || [ "$(os_id)" == "rocky" ]; then
    SYSTEMD_DIR=/usr/lib/systemd/system/
else
    SYSTEMD_DIR=/etc/systemd/system/
fi

# Generate a distinct identifier to allow multiple mountpoint-s3 services
SERVICE_ID=$(echo -n "${BUCKET_NAME}:${DIRECTORY}" | md5sum | awk '{print $1}')
SERVICE_ID=${SERVICE_ID:0:8}
SERVICE_NAME="mountpoint-s3-${SERVICE_ID}"

# Allow other users to access mount
# Needed if --allow-root or --allow-other option is set
if ! grep -q "^user_allow_other" /etc/fuse.conf
then
    echo "user_allow_other" >> /etc/fuse.conf
fi

# Write our little systemd service
## Reference: https://github.com/awslabs/mountpoint-s3/issues/441#issuecomment-1676949363
## There are a couple key changes:
## 1. Add Wants=network-online.target to ensure the service starts after network is up
## 2. Add After=default.target to ensure the service starts late. This is needed because on AL2, 
##    it takes a short while before the instance role is ready to support the S3 listobjects API.
## 3. Change the service Description to show bucket and directory
## 4. Pass options from CLI directly to mount-s3

tee > "${SERVICE_NAME}.service" <<EOF
[Unit]
Description=Mount s3://${BUCKET_NAME} at ${DIRECTORY}
Wants=network-online.target
After=default.target
AssertPathIsDirectory=${DIRECTORY}

[Service]
Type=forking
User=${POSIX_USER}
Group=${POSIX_GROUP}
ExecStart=/usr/bin/mount-s3 ${OPTIONS} ${BUCKET_NAME} ${DIRECTORY}
ExecStop=/usr/bin/fusermount -u ${DIRECTORY}

[Install]
WantedBy=default.target
EOF

# Install and start the service
sudo mv "${SERVICE_NAME}.service" "${SYSTEMD_DIR}"

# Fix selinux context for service file
# Reference: https://unix.stackexchange.com/a/573790
if [ "$(os_id)" == "rhel" ] || [ "$(os_id)" == "rocky" ]; then
    sudo restorecon "${SYSTEMD_DIR}/${SERVICE_NAME}.service"
fi

sudo systemctl daemon-reload
sudo systemctl enable "${SERVICE_NAME}"
sudo systemctl start "${SERVICE_NAME}"

# Victory song
info "Mounting s3://${BUCKET_NAME} at ${DIRECTORY}. Manage via systemctl <COMMAND> ${SERVICE_NAME}" && exit 0
