#!/usr/bin/env bash

# This script updates the kernel to match the kernel-header package available
# in the software repository.

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

handle_rocky() {
    logger "Updating Kernel on Rocky Linux" "INFO"
    dnf update -y && dnf clean all
    reboot
}

# Main function
main() {
    detect_os_version
    [ "${OS}" == "rocky" ] && handle_${OS}
}

# Call the main function
main "$@"
