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
    echo "  --prefix  pyxis install destination [$PREFIX]"
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
                ;;
            --no-intel-compiler )
                NO_INTEL_COMPILER="--no-intel-compiler"
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

# Function to install enroot on Debian-based distributions like Ubuntu 22.04
# Based on official NVIDIA enroot documentation: https://github.com/NVIDIA/enroot/blob/v3.5.0/doc/installation.md#from-packages
install_enroot_debian() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    arch="$(dpkg --print-architecture)"
    echo "Downloading enroot packages for ${arch} architecture..."
    
    curl -fSsL -O "https://github.com/NVIDIA/enroot/releases/download/v3.5.0/enroot_3.5.0-1_${arch}.deb"
    curl -fSsL -O "https://github.com/NVIDIA/enroot/releases/download/v3.5.0/enroot+caps_3.5.0-1_${arch}.deb" || {
        echo "Warning: enroot+caps download failed, continuing with basic enroot..."
    }
    
    sudo apt-get install -y ./enroot*.deb

    if [ $? -ne 0 ]; then
        echo "Error: Enroot installation failed" >&2
        exit 1
    fi

    # Verify installation
    if command -v enroot >/dev/null 2>&1; then
        echo "Enroot installation successful"
        enroot version
    else
        echo "Error: Enroot installation failed - enroot command not found" >&2
        exit 1
    fi

    cd - || exit 1
    rm -rf "$temp_dir"
}

# Function to install enroot on RHEL-based distributions
# Based on official NVIDIA enroot documentation: https://github.com/NVIDIA/enroot/blob/master/doc/installation.md
# Note: Amazon Linux 2023 does not use EPEL - it has its own repositories
install_enroot_rhel() {
    # Get architecture for RPM packages
    arch="$(uname -m)"
    
    # Install EPEL repository first (required for some dependencies on RHEL/Rocky, but not Amazon Linux)
    if [[ "${OS}" == "amzn" ]]; then
        echo "Amazon Linux detected - skipping EPEL installation (not needed)"
    else
        echo "Installing EPEL repository..."
        if command -v dnf >/dev/null 2>&1; then
            # RHEL 9+, Rocky Linux 9+
            sudo dnf install -y epel-release || {
                echo "Warning: EPEL installation failed, continuing anyway..."
            }
        elif command -v yum >/dev/null 2>&1; then
            # Older RHEL versions
            sudo yum install -y epel-release || {
                echo "Warning: EPEL installation failed, continuing anyway..."
            }
        else
            echo "Error: No suitable package manager found (dnf or yum)" >&2
            exit 1
        fi
    fi

    # Install enroot packages directly from GitHub releases
    echo "Installing enroot packages..."
    if command -v dnf >/dev/null 2>&1; then
        # RHEL 9+, Rocky Linux 9+, Amazon Linux 2023
        sudo dnf install -y "https://github.com/NVIDIA/enroot/releases/download/v3.5.0/enroot-3.5.0-1.el8.${arch}.rpm"
        sudo dnf install -y "https://github.com/NVIDIA/enroot/releases/download/v3.5.0/enroot+caps-3.5.0-1.el8.${arch}.rpm" || {
            echo "Warning: enroot+caps installation failed, continuing with basic enroot..."
        }
    elif command -v yum >/dev/null 2>&1; then
        # Amazon Linux 2
        sudo yum install -y "https://github.com/NVIDIA/enroot/releases/download/v3.5.0/enroot-3.5.0-1.el8.${arch}.rpm"
        sudo yum install -y "https://github.com/NVIDIA/enroot/releases/download/v3.5.0/enroot+caps-3.5.0-1.el8.${arch}.rpm" || {
            echo "Warning: enroot+caps installation failed, continuing with basic enroot..."
        }
    fi

    # Verify installation
    if command -v enroot >/dev/null 2>&1; then
        echo "Enroot installation successful"
        enroot version
    else
        echo "Error: Enroot installation failed - enroot command not found" >&2
        exit 1
    fi
}

# Main function to download and install enroot based on OS type
# Supports Ubuntu, Debian, RHEL 9, Rocky Linux 9, RHEL 10, Rocky Linux 10, Amazon Linux 2, Amazon Linux 2023
# Based on official NVIDIA enroot documentation: https://github.com/NVIDIA/enroot/blob/master/doc/installation.md#from-packages
download_and_install_enroot() {
    # Use existing OS and VERSION variables from detect_os_version function
    case "${OS}" in
        ubuntu|debian)
            echo "Installing enroot on ${OS} ${VERSION}"
            install_enroot_debian
            ;;
        rhel|rocky|amzn)
            echo "Installing enroot on ${OS} ${VERSION}"
            install_enroot_rhel
            ;;
        *)
            echo "Error: Unsupported OS: ${OS} ${VERSION}" >&2
            echo "Supported OS: Ubuntu, Debian, RHEL 9 and 10, Rocky Linux 9 and 10, Amazon Linux 2/2023" >&2
            exit 1
            ;;
    esac
}

download_and_install_pyxis() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    # Dynamically find SLURM installation
    SLURM_DIR=$(ls -d /opt/aws/pcs/scheduler/slurm-* 2>/dev/null | head -1)
    if [ -z "${SLURM_DIR}" ]; then
        echo "Error: SLURM installation not found in /opt/aws/pcs/scheduler/" >&2
        exit 1
    fi
    
    SLURM_VERSION=$(basename "${SLURM_DIR}")
    echo "Found SLURM installation: ${SLURM_VERSION} at ${SLURM_DIR}"

    export CFLAGS="-I${SLURM_DIR}/include"
    export DESTDIR="/etc/aws/pcs/scheduler/${SLURM_VERSION}/plugstack.conf.d/"
    
    git clone https://github.com/NVIDIA/pyxis.git
    cd pyxis/
    prefix="" libdir="" datarootdir="" datadir="" make -j4 install

    if [ $? -ne 0 ]; then
        echo "Error: pyxis compilation failed" >&2
        exit 1
    else
        echo "Pyxis compilation successful"
    fi

    ln ${DESTDIR}/slurm/spank_pyxis.so ${DESTDIR}/spank_pyxis.so
    echo "required ${DESTDIR}/spank_pyxis.so" > ${DESTDIR}/pyxis.conf
    rm ${DESTDIR}/slurm/spank_pyxis.so
    rmdir ${DESTDIR}/slurm

    cd - || exit 1
    rm -rf "$temp_dir"
}

handle_ubuntu_22.04() {
    logger "Installing deps for Ubuntu 22.04" "INFO"
    sudo apt update && sudo apt install -y git python3-pip unzip squashfuse && sudo apt clean
}

handle_rhel_9() {
    logger "Installing deps for RHEL 9" "INFO"
    sudo dnf install -y git python3-pip curl && sudo dnf clean all
}

handle_rocky_9() {
    logger "Installing deps for Rocky Linux 9" "INFO"
    sudo dnf install -y git python3-pip curl && sudo dnf clean all
}

handle_amzn_2() {
    logger "Installing deps for Amazon Linux 2" "INFO"
    sudo yum makecache && sudo yum install -y git python3-pip curl && sudo yum clean all
}

handle_rhel_10() {
    logger "Installing deps for RHEL 10" "INFO"
    sudo dnf install -y git python3-pip curl && sudo dnf clean all
}

handle_rocky_10() {
    logger "Installing deps for Rocky Linux 10" "INFO"
    sudo dnf install -y git python3-pip curl && sudo dnf clean all
}

handle_amzn_2023() {
    logger "Installing deps for Amazon Linux 2023" "INFO"
    sudo dnf install -y git python3-pip curl && sudo dnf clean all
}

# Main function
main() {
    parse_args "$@"
    detect_os_version
    handle_${OS}_${VERSION}
    download_and_install_enroot
    download_and_install_pyxis
}

# Call the main function
main "$@"
