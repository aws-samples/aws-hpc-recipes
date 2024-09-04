#!/usr/bin/env bash

# Define default value(s)
PREFIX="/opt"

# Function to print usage
usage() {
    echo "Usage: $0 [--prefix=PREFIX]"
    echo "  --prefix  Spack install destination [$PREFIX]"
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --prefix=*)
                PREFIX="${1#*=}"
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
    curl -fsSL "https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/pcs-ib/recipes/pcs/hpc_ready_ami/assets/postinstall.sh" -o "postinstall.sh"

    chmod a+x postinstall.sh
    ./postinstall.sh --prefix "$PREFIX" -fg  --no-intel-compiler

    if [ $? -ne 0 ]; then
        echo "Error: Installation failed" >&2
        exit 1
    else
        echo "Installation successful"
    fi

    cd - || exit 1
    rm -rf "$temp_dir"
}

install_packages() {
    # The Spack installer requires presence of git to check out the spack-configs repository

    # Detect the operating system
    if [ -f /etc/os-release ]; then
        # Read the contents of the /etc/os-release file
        # shellcheck disable=SC1091
        . /etc/os-release
        # Extract the operating system ID and version
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "Unable to detect the operating system." >&2
        exit 1
    fi

    # Verify if the OS is supported
    case "$OS" in
        ubuntu)
            if [ "$VERSION" == "22.04" ]; then
                echo "Running Ubuntu 22.04 scripts"
                apt update
                apt install -y git
                apt clean
            else
                echo "Unsupported Ubuntu version: $VERSION" >&2
                exit 1
            fi
            ;;
        rhel)
            if [[ "$VERSION" =~ ^9\.* ]]; then
                echo "Running RHEL 9 scripts"
                VERSION=9
                yum install -y 'dnf-command(config-manager)'
                yum makecache
                yum install -y git
                yum clean all
                rm -rf /var/cache/yum
            else
                echo "Unsupported RHEL version: $VERSION" >&2
                exit 1
            fi
            ;;
        rocky)
            if [[ "$VERSION" =~ ^9\.* ]]; then
                echo "Running Rocky Linux 9 scripts"
                VERSION=9
                yum install -y 'dnf-command(config-manager)'
                yum makecache
                yum install -y git
                yum clean all
                rm -rf /var/cache/yum
            else
                echo "Unsupported Rocky Linux version: $VERSION" >&2
                exit 1
            fi
            ;;
        amzn)
            if [ "$VERSION" == "2" ]; then
                yum makecache
                yum install -y git
                yum clean all
                rm -rf /var/cache/yum
            else
                echo "Unsupported Amazon Linux version: $VERSION" >&2
                exit 1
            fi
            ;;
        *)
            echo "Unsupported operating system: $OS" >&2
            exit 1
            ;;
    esac
}

# Main function
main() {
    parse_args "$@"
    download_and_verify_pubkey
    install_packages
    download_and_install_spack
}

# Call the main function
main "$@"
