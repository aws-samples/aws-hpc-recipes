#!/bin/bash

# Builds AMIs from matrix of distro, architecture, vendor, and source AMI
# Could be extended with additional source AMIs to do things like
# test the DLAMI or alternative base AMIs for a given distro

# To disable specific AMI builds, comment them out with '#' in the HEREDOC

# To change regions, swap out REGION and provide relevant AMIs
REGION=us-east-2
# To change HPC recipes source, update HPC_RECIPES_S3_BUCKET and HPC_RECIPES_BRANCH
HPC_RECIPES_S3_BUCKET=aws-hpc-recipes
HPC_RECIPES_BRANCH=main
# To use an alternative template, change TEMPLATE_FILE
TEMPLATE_FILE=template.json
# Change the prefix for EC2 'AMI name'
AMI_PREFIX=hpc_ready_ami
# Change the AMI volume size
VOLUME_SIZE=100

# Function to slugify a string
slugify() {
    echo "$1" | iconv -c -t ascii//TRANSLIT | sed -E 's/[~^]+//g' | sed -E 's/[^a-zA-Z0-9]+/-/g' | sed -E 's/^-+|-+$//g' | tr A-Z a-z
}

while IFS=',' read -r line; do

    # Get current time in seconds since Unix epoch
    current_time=$(date +%s)

    # Skip lines starting with comment character
    [[ $line =~ ^#.*$ ]] && continue

    # Parse fields in $line
    IFS=',' read -r field1 field2 field3 field4 <<< "$line"

    # Safened field5
    sfield4=$(slugify "$field4")

    log_file="packer-${field1}-${field2}-${sfield4}-${current_time}.log"
    echo "$field5" > $log_file
    
    packer build \
    -var "aws_region=${REGION}" \
    -var "ami_name_prefix=${AMI_PREFIX}" \
    -var "volume_size=${VOLUME_SIZE}" \
    -var-file <(./set_variables.sh ${field1} ${field2}) \
    -var "source_ami=${field3}" \
    -var "ami_description=\"HPC-Ready AMI [${field4}] (Packer)\"" \
    -var "hpc_recipes_s3_bucket=${HPC_RECIPES_S3_BUCKET}" \
    -var "hpc_recipes_branch=${HPC_RECIPES_BRANCH}" \
    ${TEMPLATE_FILE} >> ${log_file} 2>&1 &
done << EOF
amzn_2,x86_64,ami-0453ce6279422709a,AL2 Kernel 5.x
amzn_2,arm64,ami-0e3eb8e1e59049093,AL2 Kernel 5.x
rhel_9,x86_64,ami-0aa8fc2422063977a,RHEL 9 - Marketplace
rhel_9,arm64,ami-08f9f3bb075432791,RHEL 9 - Marketplace
rocky_9,x86_64,ami-01bd836275f79352c,Rocky 9.4 - Community
rocky_9,arm64,ami-018925a289077b035,Rocky 9.4 - Community
rocky_9,x86_64,ami-067daee80a6d36ac0,Rocky 9.3 - Community
rocky_9,arm64,ami-034ee457b85b2fb4f,Rocky 9.3 - Community
ubuntu_22_04,x86_64,ami-003932de22c285676,Ubuntu Server 22.04 LTS - Marketplace
ubuntu_22_04,arm64,ami-03772d93fb1879bbe,Ubuntu Server 22.04 LTS - Marketplace
amzn_2,x86_64,ami-0451026559127703a,Deep Learning Base OSS Nvidia Driver AMI (Amazon Linux 2)
ubuntu_22_04,x86_64,ami-0c8cb6d6f6dc127c9,Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)
amzn_2,arm64,ami-01629d9393241a241,Deep Learning ARM64 Base OSS Nvidia Driver GPU AMI (Amazon Linux 2)
ubuntu_22_04,arm64,ami-030b3e579315b7e71,Deep Learning ARM64 Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04)
EOF
