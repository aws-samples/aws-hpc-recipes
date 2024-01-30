#!/bin/bash
# Requires an instance profile which allows S3 PUT, internet access output on 443

# Create Setup Script
cat << 'EOF' > EC2_RHEL_SCAP_Assessment.sh
# Download and install AWS CLI V2
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"

sudo unzip "/tmp/awscliv2.zip" -d "/tmp/"

sudo "/tmp/aws/install"

# Install Openscap Scanner, Utilities and Security Guide
sudo yum install -y httpd openscap-scanner openscap-utils scap-security-guide

# Download RHEL Benchmark. Note that this path may need to be updated as the months/years go on. The current version can be found here after searching for red hat - https://public.cyber.mil/stigs/downloads/
sudo curl -O https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_RHEL_8_V1R12_STIG_SCAP_1-2_Benchmark.zip
sudo unzip -o U_RHEL_8_V1R12_STIG_SCAP_1-2_Benchmark.zip

# Check Benchmark
oscap info U_RHEL_8_V1R12_STIG_SCAP_1-2_Benchmark.xml

#Retrieve instance ID from EC2 metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Use the token to access the instance ID metadata
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Run evaluation of RHEL 8 Benchmark against EC2 Host and return results.xml and report.html in the current dir
sudo oscap xccdf eval --fetch-remote-resources --profile xccdf_mil.disa.stig_profile_MAC-2_Sensitive --results-arf ${INSTANCE_ID}_rhel8.xml --report ${INSTANCE_ID}_rhel8.html U_RHEL_8_V1R12_STIG_SCAP_1-2_Benchmark.xml

# Copy results.xml to S3 Bucket with KMS. Replace with your S3 bucket name. All other values can be left alone.
#aws s3 cp ./${INSTANCE_ID}_rhel8.xml s3://(your_S3_bucket)/${INSTANCE_ID}_rhel8.xml

aws s3 cp ./${INSTANCE_ID}_rhel8.html s3://(your_S3_bucket)/${INSTANCE_ID}_rhel8.html

# Remove xml and zip files
rm -rf U_RHEL_8_V1R11_STIG_SCAP_1-2_Benchmark.xml
EOF

# Make setup.sh executable
chmod +x EC2_RHEL_SCAP_Assessment.sh

# Execute the aws_stig_assessment.sh script
./EC2_RHEL_SCAP_Assessment.sh