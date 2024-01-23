#!/bin/bash
# Requires an instance profile which allows S3 PUT, internet access output on 443

# Create Setup Script
cat << 'EOF' > EC2_UBUNTU_SCAP_Assessment.sh
# Download and install AWS CLI V2
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"

sudo unzip "/tmp/awscliv2.zip" -d "/tmp/"

sudo "/tmp/aws/install"

# Install Openscap Scanner, Utilities and Security Guide
sudo apt update
sudo apt install libopenscap8

# Download UBUNTU Benchmark#
sudo curl -O https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_CAN_Ubuntu_20-04_LTS_V1R8_STIG_SCAP_1-2_Benchmark.zip
sudo unzip -o U_CAN_Ubuntu_20-04_LTS_V1R8_STIG_SCAP_1-2_Benchmark.zip

# Check Benchmark
oscap info U_CAN_Ubuntu_20-04_LTS_V1R8_STIG_SCAP_1-2_Benchmark.xml

#Retrieve instance ID from EC2 metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Use the token to access the instance ID metadata
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Run evaluation of UBUNTU 20.04 Benchmark against EC2 Host and return results.xml and report.html in the current dir
sudo oscap xccdf eval --fetch-remote-resources --profile xccdf_mil.disa.stig_profile_MAC-2_Sensitive --results-arf ${INSTANCE_ID}_ubuntu.xml --report ${INSTANCE_ID}_ubuntu.html U_CAN_Ubuntu_20-04_LTS_V1R8_STIG_SCAP_1-2_Benchmark.xml

# Copy results.xml to S3 Bucket with KMS. Replace with your S3 bucket name. All other values can be left alone.
#aws s3 cp ./${INSTANCE_ID}_ubuntu.xml s3://(your_S3_bucket)/${INSTANCE_ID}_ubuntu.xml

aws s3 cp ./${INSTANCE_ID}_ubuntu.html s3://(your_S3_bucket)/${INSTANCE_ID}_ubuntu.html

# Remove xml and zip files
rm -rf U_CAN_Ubuntu_20-04_LTS_V1R8_STIG_SCAP_1-2_Benchmark.xml
EOF

# Make setup.sh executable
chmod +x EC2_UBUNTU_SCAP_Assessment.sh

# Execute the aws_stig_assessment.sh script
./EC2_UBUNTU_SCAP_Assessment.sh