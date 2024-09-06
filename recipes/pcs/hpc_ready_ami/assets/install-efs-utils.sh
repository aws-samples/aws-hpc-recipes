#!/usr/bin/env bash

# This script installs EFS utils either from a system
# repository or by building from source.

set -o errexit -o pipefail -o nounset

if [ -f "common.sh" ]; then . common.sh; fi

build_and_install_rpm() {
    logger "RPM install from source" "INFO"
    sudo yum -y install git rpm-build make rust cargo openssl-devel
    # Create a temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1
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

handle_ubuntu_22.04() {
    logger "Updating Ubuntu 22.04" "INFO"
    build_and_install_deb
}

handle_rhel_9() { 
    logger "Updating RHEL 9" "INFO"
    build_and_install_rpm
}

handle_rocky_9() {
    logger "Updating Rocky Linux 9" "INFO"
    build_and_install_rpm
}

handle_amzn_2() {
    logger "Updating Amazon Linux 2" "INFO"
    sudo yum -y install amazon-efs-utils
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
