#!/bin/bash
set -e

# Install Mountpoint for S3 as per its GitHub page
#
# https://github.com/awslabs/mountpoint-s3
#
# Usage: sudo bash install.sh

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

download() {
    # Some operating systems don't have curl, so use wget instead
    curl -O "${1}" || wget "${1}"
}

install_deb() {
    # Install dependencies for Debian family operating systems
    download https://s3.amazonaws.com/mountpoint-s3-release/latest/"${OS_ARCH}"/mount-s3.deb
    sudo apt-get install -y ./mount-s3.deb && rm -rf mount-s3.deb 
}

install_rpm() {
    # Install dependencies for RHEL family operating systems
    download https://s3.amazonaws.com/mountpoint-s3-release/latest/"${OS_ARCH}"/mount-s3.rpm
    sudo yum install -y ./mount-s3.rpm && rm -rf mount-s3.rpm
}

OS_ID=$(os_id)
OS_ARCH=$(uname -m)

# Halt if on Ubuntu 22 as it's current unsupported
# It's unsupported because Ubuntu 22 doesn't work well with libfuse2
if [[ $OS_ID == "ubuntu" ]]; then
    OS_RELEASE=$(awk '/^DISTRIB_RELEASE=/' /etc/*-release | awk -F'=' '{ print tolower($2) }' | tr -d '"')
    if [[ "${OS_RELEASE}" == "22.04" ]]; then
        die "Unsupported Ubuntu version"
    fi
fi

case $OS_ID in
    amzn)
        info "Installing dependencies for Amazon Linux"
        install_rpm
        ;;
    ubuntu)
        info "Installing dependencies for Ubuntu"
        install_deb
        ;;
    rhel)
        info "Installing dependencies for RHEL"
        install_rpm
        ;;
    debian)
        info "Installing dependencies for Debian"
        install_deb
        ;;
    rocky)
        info "Installing dependencies for Rocky Linux"
        install_rpm
        ;;
    centos)
        info "Installing dependencies for CentOS"
        install_rpm
        ;;
    fedora)
        info "Installing dependencies for Fedora"
        install_rpm
        ;;
    *)
        die "Unsupported OS"
        ;;
esac

info "Installation complete" && exit 0
