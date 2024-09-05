#!/usr/bin/env bash

# This script updates the OS and base packages for AMIs from 
# operating systems supported by AWS PCS. It is intended to 
# replace the UpdateOS ImageBuilder component with a solution
# that is more flexible to the specifics of each supported OS.
#
# It should be followed by an explicit, managed reboot 
# before installing additional software. 

set -o errexit -o pipefail -o nounset

if [ -f "common.sh" ]; then . common.sh; fi

handle_ubuntu_22.04() {
    logger "Updating Ubuntu 22.04" "INFO"
    apt-get update && apt-get upgrade -y && apt-get autoremove -y && apt-get autoclean
}

handle_rhel_9() { 
    logger "Updating RHEL 9" "INFO"
    dnf update -y && dnf clean all
}

handle_rocky_9() {
    logger "Updating Rocky Linux 9" "INFO"
    dnf update -y && dnf clean all
}

handle_amzn_2() {
    logger "Updating Amazon Linux 2" "INFO"
    yum update -y && yum clean all
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
