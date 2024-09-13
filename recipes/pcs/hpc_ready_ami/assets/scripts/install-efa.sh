#!/usr/bin/env bash

# Define default value(s)
# EFA_INSTALLER_VERSION="1.34"
EFA_INSTALLER_VERSION="latest"

# Function to print usage
usage() {
    echo "Usage: $0 [--efa-installer-version=EFA_INSTALLER_VERSION]"
    echo "  --efa-installer-version  EFA software installer version [$EFA_INSTALLER_VERSION]"
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --aws-region=*)
                AWS_REGION="${1#*=}"
                ;;
            --efa-installer-version=*)
                EFA_INSTALLER_VERSION="${1#*=}"
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
download_verify_and_install_software() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    # Download EFA installer tarball
    curl -fsSL "https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz" -o "aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz"

    # Unpack the EFA software and install
    tar zxf "aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz" && cd "aws-efa-installer"
    sudo ./efa_installer.sh  -y

    if [ $? -ne 0 ]; then
        echo "Error: Installation failed" >&2
        exit 1
    else
        echo "Installation successful"
    fi

    # Disable ptrace protection
    # Set the file path
    PTRACE_FILE_PATH="/etc/sysctl.d/10-ptrace.conf"

    # Create the file if it doesn't exist
    if [ ! -f "$PTRACE_FILE_PATH" ]; then
        sudo touch "$PTRACE_FILE_PATH"
    fi

    # Check if the line already exists in the file
    if grep -q "^kernel.yama.ptrace_scope" "$PTRACE_FILE_PATH"; then
        # Replace the existing line with the new value
        sudo sed -i "/^kernel.yama.ptrace_scope/c\kernel.yama.ptrace_scope = 0" "$PTRACE_FILE_PATH"
        echo "Line 'kernel.yama.ptrace_scope' updated to '0' in $PTRACE_FILE_PATH"
    else
        # Append the line to the file
        echo "kernel.yama.ptrace_scope = 0" | sudo tee -a "$PTRACE_FILE_PATH" > /dev/null
        echo "Line 'kernel.yama.ptrace_scope = 0' added to $PTRACE_FILE_PATH"
    fi

    cd - || exit 1
    rm -rf "$temp_dir"
}

# Main function
main() {
    parse_args "$@"
    download_and_verify_pubkey
    download_verify_and_install_software
}

# Call the main function
main "$@"
