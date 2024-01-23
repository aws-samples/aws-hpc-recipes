#!/bin/bash
# Requires an instance profile which allows S3 PUT, internet access output on 443
#NOTE THAT THIS COMMAND WILL TAKE ~20 MINUTES TO COMPLETE. You can login to the EC2 instance and type sudo cat /var/log/cloud-init-output.log to see the current OSCAP rule being verified.

# Create Setup Script
cat << 'EOF' > EC2_AL2_SCAP_Assessment.sh
# Download and install AWS CLI V2
sudo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"

sudo unzip "/tmp/awscliv2.zip" -d "/tmp/"

sudo "/tmp/aws/install"

# Install Openscap Scanner, Utilities and Security Guide
sudo yum install -y httpd openscap-scanner openscap-utils scap-security-guide

# Download RHEL Benchmark#
sudo curl -O https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_RHEL_7_V3R14_STIG_SCAP_1-2_Benchmark.zip
sudo unzip -o U_RHEL_7_V3R14_STIG_SCAP_1-2_Benchmark.zip

# Check Benchmark
sudo oscap info /usr/share/xml/scap/ssg/content/ssg-amzn2-xccdf.xml

#Retrieve instance ID from EC2 metadata using IMDSv2
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Use the token to access the instance ID metadata
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

# Run evaluation of RHEL 7 Benchmark against EC2 Host and return results.xml and report.html in the current dir
sudo oscap xccdf eval --profile stig-rhel7-disa --results-arf ./${INSTANCE_ID}_al2.xml --report ./${INSTANCE_ID}_al2.html /usr/share/xml/scap/ssg/content/ssg-amzn2-xccdf.xml

# Copy results.xml to S3 Bucket with KMS
#aws s3 cp ./${INSTANCE_ID}_al2.xml s3://pcluster-stig/results/${INSTANCE_ID}_al2.xml

aws s3 cp ./${INSTANCE_ID}_al2.html s3://pcluster-stig/results/${INSTANCE_ID}_al2.html

# Remove xml and zip files
rm -rf U_RHEL_7_V3R14_STIG_SCAP_1-2_Benchmark.xml
EOF

# Make setup.sh executable
chmod +x EC2_AL2_SCAP_Assessment.sh

# Execute the aws_stig_assessment.sh script
./EC2_AL2_SCAP_Assessment.sh