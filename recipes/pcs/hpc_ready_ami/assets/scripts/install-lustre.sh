#!/usr/bin/env bash

# This script enables support for FSx for Lustre

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

install_redhat9_or_rocky9() {
    # Ref: https://docs.aws.amazon.com/fsx/latest/LustreGuide/install-lustre-client.html
    # This only covers the happy path where kernel is 5.14.0-427*
    curl https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-rpm-public-key.asc -o /tmp/fsx-rpm-public-key.asc
    sudo rpm --import /tmp/fsx-rpm-public-key.asc
    sudo curl https://fsx-lustre-client-repo.s3.amazonaws.com/el/9/fsx-lustre-client.repo -o /etc/yum.repos.d/aws-fsx.repo
    sudo yum clean all
    sudo yum install -y kmod-lustre-client lustre-client
    sudo yum clean all
}

handle_ubuntu_22.04() {
    logger "Installing on Ubuntu 22.04" "INFO"
    # Ref: https://docs.aws.amazon.com/fsx/latest/LustreGuide/install-lustre-client.html
    # This only covers the happy path where kernel is 5.14.0-427*
    wget -O - https://fsx-lustre-client-repo-public-keys.s3.amazonaws.com/fsx-ubuntu-public-key.asc | gpg --dearmor | sudo tee /usr/share/keyrings/fsx-ubuntu-public-key.gpg >/dev/null
    sudo bash -c 'echo "deb [signed-by=/usr/share/keyrings/fsx-ubuntu-public-key.gpg] https://fsx-lustre-client-repo.s3.amazonaws.com/ubuntu jammy main" > /etc/apt/sources.list.d/fsxlustreclientrepo.list && apt-get update'
    sudo apt install -y lustre-client-modules-aws
    sudo apt clean
}

handle_rhel_9() { 
    logger "Installing on RHEL 9" "INFO"
    install_redhat9_or_rocky9
}

handle_rocky_9() {
    logger "Installing on Rocky Linux 9" "INFO"
    install_redhat9_or_rocky9
}

handle_amzn_2() {
    logger "Installing on Amazon Linux 2" "INFO"
    # Ref: https://docs.aws.amazon.com/fsx/latest/LustreGuide/install-lustre-client.html
    sudo amazon-linux-extras install -y lustre
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
