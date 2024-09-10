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

# Define default value(s)
PREFIX="/opt"
NO_ARM_COMPILER=""
NO_INTEL_COMPILER=""

# Function to print usage
usage() {
    echo "Usage: $0 [--prefix=PREFIX]"
    echo "  --prefix  Spack install destination [$PREFIX]"
    echo "  --no-arm-compiler   Skip installation of the ARM compiler"
    echo "  --no-intel-compiler  Skip installation of the Intel compiler"
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix=*)
                PREFIX="${1#*=}"
                ;;
            --no-arm-compiler )
                NO_ARM_COMPILER="--no-arm-compiler"
                shift
                ;;
            --no-intel-compiler )
                NO_INTEL_COMPILER="--no-intel-compiler"
                shift
                ;;
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

# Function to download and install EFA software
# Ref: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html#efa-start-enable
download_and_install_spack() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    # Download Spack install script
    # TODO - replace with link to file in spack-configs GitHub repo
    # ref: https://raw.githubusercontent.com/spack/spack-configs/main/AWS/parallelcluster/postinstall.sh
    curl -fsSL "https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/pcs-ib/recipes/pcs/hpc_ready_ami/assets/scripts/postinstall.sh" -o "postinstall.sh"

    chmod a+x postinstall.sh
    ./postinstall.sh -fg --prefix "$PREFIX" ${NO_ARM_COMPILER} ${NO_INTEL_COMPILER}

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
    apt update && apt install -y git && apt clean
}

handle_rhel_9() { 
    logger "Installing deps for RHEL 9" "INFO"
    dnf install -y git && dnf clean all
}

handle_rocky_9() {
    logger "Installing deps for Rocky Linux 9" "INFO"
    dnf install -y git && dnf clean all
}

handle_amzn_2() {
    logger "Installing deps for Amazon Linux 2" "INFO"
    yum makecache && yum install -y git && yum clean all
}

install_dependencies() {
    # The Spack installer requires presence of git to check out the spack-configs repository

    # Common library that helps implement OS-specific code paths
    if [ -f "common.sh" ]; then . common.sh; fi
    detect_os_version
    handle_${OS}_${VERSION}

}

# Main function
main() {
    parse_args "$@"
    detect_os_version
    handle_${OS}_${VERSION}
    download_and_install_spack
}

# Call the main function
main "$@"