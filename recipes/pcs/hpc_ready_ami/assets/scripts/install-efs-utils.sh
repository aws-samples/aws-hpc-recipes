#!/usr/bin/env bash

# This script installs EFS utils either from a system
# repository or by building from source.

set -o errexit -o pipefail -o nounset

# Find the directory of the current script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Search for common.sh in the current directory and parent directory
if [ -f "${SCRIPT_DIR}/common.sh" ]; then
    . "${SCRIPT_DIR}/common.sh"
elif [ -f "${SCRIPT_DIR}/../common.sh" ]; then
    . "${SCRIPT_DIR}/../common.sh"
else
    echo "Error: common.sh not found!" >&2
    exit 1
fi

build_and_install_rpm() {
    logger "RPM install from source" "INFO"
    sudo yum -y install git rpm-build make rust cargo openssl-devel
    # Create a temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1
    # TODO: we should not build from `master` branch
    git clone https://github.com/aws/efs-utils
    cd efs-utils
    make rpm
    sudo yum -y install build/amazon-efs-utils*rpm
    cd - || exit 1
    rm -rf "$temp_dir"
}

build_and_install_deb() {
    logger "DEB install from source" "INFO"
    sudo apt-get update
    sudo apt-get -y install git binutils rustc cargo pkg-config libssl-dev
    # Create a temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1
    git clone https://github.com/aws/efs-utils
    cd efs-utils
    ./build-deb.sh
    sudo apt-get -y install ./build/amazon-efs-utils*deb
    cd - || exit 1
    rm -rf "$temp_dir"
}

increase_watchdog_poll_interval() {

# Increase EFS-utils watchdog poll interval to 10 seconds
# Ref: https://github.com/aws/aws-parallelcluster-cookbook/pull/2357

    if [ -f "/etc/amazon/efs/efs-utils.conf" ]; then
        sudo sed -i 's/^poll_interval_sec = 1$/poll_interval_sec = 10/' /etc/amazon/efs/efs-utils.conf
    fi
}

handle_ubuntu_22.04() {
    logger "Installing on Ubuntu 22.04" "INFO"
    build_and_install_deb
    increase_watchdog_poll_interval
}

handle_rhel_9() { 
    logger "Installing on RHEL 9" "INFO"
    build_and_install_rpm
    increase_watchdog_poll_interval
}

handle_rocky_9() {
    logger "Installing on Rocky Linux 9" "INFO"
    build_and_install_rpm
    increase_watchdog_poll_interval
}

handle_amzn_2() {
    logger "Installing on Amazon Linux 2" "INFO"
    sudo yum -y install amazon-efs-utils
    increase_watchdog_poll_interval
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
