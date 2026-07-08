#!/usr/bin/env bash

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


# Function to print usage
usage() {
    echo "Usage: $0"
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            *)
                echo "Invalid option: $1" >&2
                usage
                exit 1
                ;;
        esac
        shift
    done
}

# Function to download and verify public key
download_and_verify_pubkey() {
    echo "Skipping public key download and verification for now"
}

# Function to download and install CVMFS (and indirectly EESSI)
download_and_install_eessi() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    # Download EESSI install script from EESSI/eessi-demo
    curl -fsSL "https://raw.githubusercontent.com/EESSI/eessi-demo/refs/heads/main/scripts/install_cvmfs_eessi.sh" -o "install_cvmfs_eessi.sh"

    chmod a+x install_cvmfs_eessi.sh
    sudo ./install_cvmfs_eessi.sh

    if [ $? -ne 0 ]; then
        echo "Error: Installation failed" >&2
        exit 1
    else
        echo "Installation successful"
    fi

    cd - || exit 1
    rm -rf "$temp_dir"
}

handle_ubuntu_22.04() {
    logger "Installing deps for Ubuntu 22.04" "INFO"
    sudo apt update && sudo apt install -y lsb-release wget && sudo apt clean
}

handle_rhel_9() { 
    logger "Installing deps for RHEL 9" "INFO"
}

handle_rocky_9() {
    logger "Installing deps for Rocky Linux 9" "INFO"
}

handle_amzn_2() {
    logger "Installing deps for Amazon Linux 2" "INFO"
}

# Main function
main() {
    parse_args "$@"
    detect_os_version
    handle_${OS}_${VERSION}
    eessi
}

# Call the main function
main "$@"
