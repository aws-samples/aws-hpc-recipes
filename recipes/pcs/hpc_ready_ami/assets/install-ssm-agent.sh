#!/usr/bin/env bash

# This script installs SSM Agent. There is no official ImageBuilder component for this.

set -o errexit -o pipefail -o nounset

if [ -f "common.sh" ]; then . common.sh; fi

handle_ubuntu_22.04() {
    # Ref: https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-ubuntu-64-snap.html
    # Uses Snaps rather than apt to install the agent
    # SSM Agent is installed, by default, on Ubuntu Server 22.04 LTS, 20.04, 18.04, and 16.04 LTS 64-bit AMIs with an identifier of 20180627 or later.
    # This will force a reinstall
    logger "Installing on Ubuntu 22.04" "INFO"
    sudo snap install amazon-ssm-agent --classic
    sudo snap services amazon-ssm-agent
}

handle_rhel_9() {
    # Ref: https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-rhel-8-9.html
    # Requires Python 2 or 3 to be installed
    logger "Installing on RHEL 9" "INFO"
    if [ "${ARCHITECTURE}" == "arm64" ]; then
        TARGET="linux_arm64"
    elif [ "${ARCHITECTURE}" == "x86_64" ]; then
        TARGET="linux_amd64"
    fi
    sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/${TARGET}/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent && sudo systemctl start amazon-ssm-agent && sudo systemctl status amazon-ssm-agent
}

handle_rocky_9() {
    # Ref: https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-rocky.html
    # Requires Python 2 or 3 to be installed
    logger "Installing on Rocky Linux 9" "INFO"
    if [ "${ARCHITECTURE}" == "arm64" ]; then
        TARGET="linux_arm64"
    elif [ "${ARCHITECTURE}" == "x86_64" ]; then
        TARGET="linux_amd64"
    fi
    sudo dnf install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/${TARGET}/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent && sudo systemctl start amazon-ssm-agent && sudo systemctl status amazon-ssm-agent
}

handle_amzn_2() {
    # Ref: https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-al2.html
    # SSM Agent is expected to already be installed on Amazon Linux 2
    logger "Installing on Amazon Linux 2" "INFO"
    if [ "${ARCHITECTURE}" == "arm64" ]; then
        TARGET="linux_arm64"
    elif [ "${ARCHITECTURE}" == "x86_64" ]; then
        TARGET="linux_amd64"
    fi
    sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/${TARGET}/amazon-ssm-agent.rpm
    sudo systemctl enable amazon-ssm-agent && sudo systemctl start amazon-ssm-agent && sudo systemctl status amazon-ssm-agent
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
