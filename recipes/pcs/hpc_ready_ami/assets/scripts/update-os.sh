#!/usr/bin/env bash

# This script updates the OS and base packages for AMIs from 
# operating systems supported by AWS PCS. It is intended to 
# replace the UpdateOS ImageBuilder component with a solution
# that is more flexible to the specifics of each supported OS.
#
# It should be followed by an explicit, managed reboot 
# before installing additional software. 

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

handle_ubuntu_22.04() {
    logger "Updating Ubuntu 22.04" "INFO"
    sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y && sudo apt-get autoclean
}

handle_rhel_9() { 
    logger "Updating RHEL 9" "INFO"
    # Do not upgrade kernel or risk breaking EFA and/or Lustre support
    sudo dnf update --exclude=kernel* -y && sudo dnf clean all
}

handle_rocky_9() {
    logger "Updating Rocky Linux 9" "INFO"
    # Do not upgrade kernel or risk breaking EFA and/or Lustre support
    # Passing --exclude=kernel* does not work on Rocky-9-EC2-Base-9.4
    sudo dnf update --security -y && sudo dnf clean all
}

handle_amzn_2() {
    logger "Updating Amazon Linux 2" "INFO"
    sudo yum update -y && sudo yum clean all
}

# Main function
main() {
    detect_os_version
    handle_${OS}_${VERSION}
}

# Call the main function
main "$@"
