#!/usr/bin/bash

PCS_AGENT_VERSION="latest"
AWS_REGION="us-east-1"

PUBKEY_ID="7EEF030EDDF5C21C"
PUBKEY_EXPECTED_FINGERPRINT="1C24 32C1 862F 64D1 F90A  239A 7EEF 030E DDF5 C21C"

# create a temporary directory
temp_dir=$(mktemp -d)
cd $temp_dir
# Import and validate public key
curl -O https://aws-pcs-repo-public-keys-${AWS_REGION}.s3.amazonaws.com/aws-pcs-public-key.pub && \
    gpg --import aws-pcs-public-key.pub
# Get the actual fingerprint
ACTUAL_FINGERPRINT=$(gpg --fingerprint --with-fingerprint ${PUBKEY_ID} | grep fingerprint | awk '{print $2}' | tr -d '[:space:]')
# Compare the fingerprints
if [ "$ACTUAL_FINGERPRINT" != "$PUBKEY_EXPECTED_FINGERPRINT" ]; then
    echo "Error: Fingerprint mismatch for key ${PUBKEY_ID}"
    echo "Expected: $EXPECTED_FINGERPRINT"
    echo "Actual: $ACTUAL_FINGERPRINT"
    exit 1
else
    echo "Fingerprint matches for key ${PUBKEY_ID}"
fi

# Download agent tarball
curl -O https://aws-pcs-repo-${AWS_REGION}.s3.amazonaws.com/aws-pcs-agent/aws-pcs-agent-v1-${PCS_AGENT_VERSION}.tar.gz
# Download and verify signature file
curl -O https://aws-pcs-repo-${AWS_REGION}.s3.amazonaws.com/aws-pcs-agent/aws-pcs-agent-v1-${PCS_AGENT_VERSION}.tar.gz.sig
# Verify the signature
gpg --verify aws-pcs-agent-v1-latest.tar.gz.sig aws-pcs-agent-v1-latest.tar.gz

# Check the exit status of the previous command
if [ $? -ne 0 ]; then
    echo "Error: Signature verification failed for aws-pcs-agent-v1-latest.tar.gz"
    exit 1
else
    echo "Signature verification successful for aws-pcs-agent-v1-latest.tar.gz"
fi

# Unpack the agent and install
tar zxvf aws-pcs-agent-v1-${PCS_AGENT_VERSION}.tar.gz && cd aws-pcs-agent
./installer.sh -y

if [ $? -ne 0 ]; then
    echo "Error: installation failed for aws-pcs-agent-v1-latest.tar.gz"
    exit 1
else
    echo "Installation successful for aws-pcs-agent-v1-latest.tar.gz"
fi

cd ../../
rm -rf $temp_dir
