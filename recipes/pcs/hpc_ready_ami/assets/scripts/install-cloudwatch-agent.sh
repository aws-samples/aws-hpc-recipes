#!/usr/bin/env bash

# This script installs the CloudWatch agent.
# We don't use the AWS-provided ImageBuilder 
# component because it's doesn't support all the
# operating systems that works with AWS PCS. 

set -o errexit -o pipefail -o nounset

if [ -f "common.sh" ]; then . common.sh; fi

handle_ubuntu_22.04() {
    logger "Installing on Ubuntu 22.04" "INFO"
    if [ "${ARCHITECTURE}" == "arm64" ]; then
        TARGET="arm64"
    elif [ "${ARCHITECTURE}" == "x86_64" ]; then
        TARGET="amd64"
    fi
    curl -fSsL "https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/${TARGET}/latest/amazon-cloudwatch-agent.deb" -o "amazon-cloudwatch-agent.deb"
    sudo dpkg -i -E ./amazon-cloudwatch-agent.deb
}

handle_rhel_9() { 
    logger "Installing on RHEL 9" "INFO"
    if [ "${ARCHITECTURE}" == "arm64" ]; then
        TARGET="arm64"
    elif [ "${ARCHITECTURE}" == "x86_64" ]; then
        TARGET="amd64"
    fi
    sudo dnf install -y "https://amazoncloudwatch-agent.s3.amazonaws.com/redhat/${TARGET}/latest/amazon-cloudwatch-agent.rpm"
}

handle_rocky_9() {
    logger "Installing on Rocky Linux 9" "INFO"
    if [ "${ARCHITECTURE}" == "arm64" ]; then
        TARGET="arm64"
    elif [ "${ARCHITECTURE}" == "x86_64" ]; then
        TARGET="amd64"
    fi
    sudo dnf install -y "https://amazoncloudwatch-agent.s3.amazonaws.com/redhat/${TARGET}/latest/amazon-cloudwatch-agent.rpm"
}

handle_amzn_2() {
    logger "Installing on Amazon Linux 2" "INFO"
    sudo yum -y install amazon-cloudwatch-agent
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
