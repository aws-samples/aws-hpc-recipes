#!/usr/bin/env bash

# Define default values
AWS_REGION="us-east-1"
PCS_SLURM_VERSION="23.11"
PCS_SLURM_INSTALLER_VERSION="latest"

# Function to print usage
usage() {
    echo "Usage: $0 [--aws-region=AWS_REGION] [--pcs-slurm-installer-version=PCS_SLURM_INSTALLER_VERSION] [--pcs-slurm-version=PCS_SLURM_VERSION]"
    echo "  --aws-region  AWS region for installer repo [$AWS_REGION]"
    echo "  --pcs-slurm-version  Slurm major version to install [$PCS_SLURM_VERSION]"
    echo "  --pcs-slurm-installer-version  AWS PCS Slurm installer version [$PCS_SLURM_INSTALLER_VERSION]"
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --aws-region=*)
                AWS_REGION="${1#*=}"
                ;;
             --pcs-slurm-version=*)
                PCS_SLURM_VERSION="${1#*=}"
                ;;
            --pcs-slurm-installer-version=*)
                PCS_SLURM_INSTALLER_VERSION="${1#*=}"
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
    local PUBKEY_ID="7EEF030EDDF5C21C"
    local PUBKEY_EXPECTED_FINGERPRINT="1C24 32C1 862F 64D1 F90A  239A 7EEF 030E DDF5 C21C"

    # Create a temporary directory
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    # Import and validate public key
    curl -fsSL "https://aws-pcs-repo-public-keys-${AWS_REGION}.s3.amazonaws.com/aws-pcs-public-key.pub" -o aws-pcs-public-key.pub && \
        sudo gpg --import aws-pcs-public-key.pub

    # # Get the actual fingerprint
    # local ACTUAL_FINGERPRINT=$(gpg --fingerprint "$PUBKEY_ID" | grep -i "Key fingerprint" | awk -F'=' '{print $2}' | tr -d '[:space:]')
    # PUBKEY_EXPECTED_FINGERPRINT=$(echo -n $PUBKEY_EXPECTED_FINGERPRINT | tr -d '[:space:]')

    # # Compare the fingerprints
    # if [ "$ACTUAL_FINGERPRINT" != "$PUBKEY_EXPECTED_FINGERPRINT" ]; then
    #     echo "Error: Fingerprint mismatch for key ${PUBKEY_ID}" >&2
    #     echo "Expected: $PUBKEY_EXPECTED_FINGERPRINT" >&2
    #     echo "Actual: $ACTUAL_FINGERPRINT" >&2
    #     exit 1
    # else
    #     echo "Fingerprint matches for key ${PUBKEY_ID}"
    # fi

    cd - || exit 1
    rm -rf "$temp_dir"
}

# Function to download and verify PCS agent
download_verify_and_install_software() {
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    # Download Slurm software tarball
    curl -fsSL "https://aws-pcs-repo-${AWS_REGION}.s3.amazonaws.com/aws-pcs-slurm/aws-pcs-slurm-${PCS_SLURM_VERSION}-installer-${PCS_SLURM_INSTALLER_VERSION}.tar.gz" -o "aws-pcs-slurm-${PCS_SLURM_VERSION}-installer-${PCS_SLURM_INSTALLER_VERSION}.tar.gz"

    # # Download and verify signature file
    # curl -fsSL "https://aws-pcs-repo-${AWS_REGION}.s3.amazonaws.com/aws-pcs-slurm/aws-pcs-slurm-${PCS_SLURM_VERSION}-installer-${PCS_SLURM_INSTALLER_VERSION}.tar.gz.sig" -o "aws-pcs-slurm-${PCS_SLURM_VERSION}-installer-${PCS_SLURM_INSTALLER_VERSION}.tar.gz.sig"
    # # Verify the signature
    # gpg --verify aws-pcs-slurm-${PCS_SLURM_VERSION}-installer-${PCS_SLURM_INSTALLER_VERSION}.tar.gz.sig aws-pcs-slurm-${PCS_SLURM_VERSION}-installer-${PCS_SLURM_INSTALLER_VERSION}.tar.gz

    # # Check the exit status of the previous command
    # if [ $? -ne 0 ]; then
    #     echo "Error: Signature verification failed" >&2
    #     exit 1
    # else
    #     echo "Signature verification successful"
    # fi

    # Unpack the agent and install
    tar zxf "aws-pcs-slurm-${PCS_SLURM_VERSION}-installer-${PCS_SLURM_INSTALLER_VERSION}.tar.gz" && cd "aws-pcs-slurm-${PCS_SLURM_VERSION}-installer"
    sudo ./installer.sh -y

    if [ $? -ne 0 ]; then
        echo "Error: Installation failed" >&2
        exit 1
    else
        echo "Installation successful"
    fi

    cd - || exit 1
    rm -rf "$temp_dir"
}

configure_paths() {
    local SLURM_INSTALL_PATH="/opt/aws/pcs/scheduler/slurm-${PCS_SLURM_VERSION}"

sudo tee /etc/profile.d/slurm.sh << EOF
PATH=\$PATH:${SLURM_INSTALL_PATH}/bin
MANPATH=\$MANPATH:${SLURM_INSTALL_PATH}/share/man
export PATH MANPATH
EOF

    # Add slurm libraries to /etc/ld.so.conf.d/
    echo "${SLURM_INSTALL_PATH}/lib" | sudo tee /etc/ld.so.conf.d/slurm.conf > /dev/null && sudo chmod 0644 /etc/ld.so.conf.d/slurm.conf && sudo ldconfig
    
}

# Main function
main() {
    parse_args "$@"
    download_and_verify_pubkey
    download_verify_and_install_software
    configure_paths
}

# Call the main function
main "$@"
