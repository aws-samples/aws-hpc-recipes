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
    # As of 2024-09-13, upgrading kernel to 5.14.0-427.33.1.el9_4.x86_64
    # and does not break EFA or Lustre support 
    sudo dnf update -y && sudo dnf clean all
}

handle_rocky_9() {
    logger "Updating Rocky Linux 9" "INFO"
    # As of 2024-09-11, upgrading kernel to 5.14.0-427.33.1.el9_4.x86_64
    # and does not break EFA or Lustre support 
    sudo dnf update -y && sudo dnf clean all
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
