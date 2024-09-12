#!/bin/bash

# Builds AMIs from matrix of distro, architecture, vendor, and source AMI
# Could be extended with additional source AMIs to do things like
# test the DLAMI or alternative base AMIs for a given distro

REGION=us-east-2
HPC_RECIPES_S3_BUCKET=aws-hpc-recipes-dev
HPC_RECIPES_BRANCH=pcs-ib

while IFS=',' read -r line; do

    # Get current time in seconds since Unix epoch
    current_time=$(date +%s)

    # Skip lines starting with comment character
    [[ $line =~ ^#.*$ ]] && continue

    # Parse fields in $line
    IFS=',' read -r field1 field2 field3 field4 field5 <<< "$line"

    log_file="packer-${field1}-${field2}-${field3}-${current_time}.log"
    echo "$field5" > $log_file
    
    packer build \
    -var "aws_region=$REGION" \
    -var "ami_name_prefix=packer_test" \
    -var-file <(./set_variables.sh ${field1} ${field2} ${field3}) \
    -var "source_ami=${field4}" \
    -var "ami_description=\"Packer test build - ${field5}\"" \
    -var "hpc_recipes_s3_bucket=${HPC_RECIPES_S3_BUCKET}" \
    -var "hpc_recipes_branch=${HPC_RECIPES_BRANCH}" \
    template.json >> ${log_file} 2>&1 &
done << EOF
amzn_2,x86_64,intel,ami-0453ce6279422709a,AL2 Kernel 5.x
amzn_2,x86_64,amd,ami-0453ce6279422709a,AL2 Kernel 5.x
amzn_2,arm64,aws,ami-0e3eb8e1e59049093,AL2 Kernel 5.x
rhel_9,x86_64,intel,ami-0aa8fc2422063977a,RHEL 9 - Marketplace
rhel_9,x86_64,amd,ami-0aa8fc2422063977a,RHEL 9 - Marketplace
rhel_9,arm64,aws,ami-08f9f3bb075432791,RHEL 9 - Marketplace
rocky_9,x86_64,intel,ami-01bd836275f79352c,Rocky 9.4 - Community
rocky_9,x86_64,amd,ami-01bd836275f79352c,Rocky 9.4 - Community
rocky_9,arm64,aws,ami-018925a289077b035,Rocky 9.4 - Community
ubuntu_22_04,x86_64,intel,ami-003932de22c285676,Ubuntu Server 22.04 LTS - Marketplace
ubuntu_22_04,x86_64,amd,ami-003932de22c285676,Ubuntu Server 22.04 LTS - Marketplace
ubuntu_22_04,arm64,aws,ami-03772d93fb1879bbe,Ubuntu Server 22.04 LTS - Marketplace
EOF
