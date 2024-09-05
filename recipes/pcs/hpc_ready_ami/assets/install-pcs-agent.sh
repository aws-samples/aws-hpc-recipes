#!/usr/bin/env bash

# Define default values
AWS_REGION="us-east-1"
PCS_AGENT_INSTALLER_VERSION="latest"

# Function to print usage
usage() {
    echo "Usage: $0 [--aws-region=AWS_REGION] [--pcs-agent-installer-version=PCS_AGENT_INSTALLER_VERSION]"
    echo "  --aws-region  AWS region for installer repo [$AWS_REGION]"
    echo "  --pcs-agent-installer-version   AWS PCS agent installer version [$PCS_AGENT_INSTALLER_VERSION]"
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --aws-region=*)
                AWS_REGION="${1#*=}"
                ;;
            --pcs-agent-installer-version=*)
                PCS_AGENT_INSTALLER_VERSION="${1#*=}"
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
        gpg --import aws-pcs-public-key.pub

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

    # Download agent tarball
    curl -fsSL "https://aws-pcs-repo-${AWS_REGION}.s3.amazonaws.com/aws-pcs-agent/aws-pcs-agent-v1-${PCS_AGENT_INSTALLER_VERSION}.tar.gz" -o aws-pcs-agent.tar.gz

    # Download and verify signature file
    curl -fsSL "https://aws-pcs-repo-${AWS_REGION}.s3.amazonaws.com/aws-pcs-agent/aws-pcs-agent-v1-${PCS_AGENT_INSTALLER_VERSION}.tar.gz.sig" -o aws-pcs-agent.tar.gz.sig

    # Verify the signature
    gpg --verify aws-pcs-agent.tar.gz.sig aws-pcs-agent.tar.gz

    # Check the exit status of the previous command
    if [ $? -ne 0 ]; then
        echo "Error: Signature verification failed" >&2
        exit 1
    else
        echo "Signature verification successful"
    fi

    # Unpack the agent and install
    tar zxf aws-pcs-agent.tar.gz && cd aws-pcs-agent
    ./installer.sh -y

    if [ $? -ne 0 ]; then
        echo "Error: Installation failed" >&2
        exit 1
    else
        echo "Installation successful"
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
