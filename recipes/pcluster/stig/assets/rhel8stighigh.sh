#This command, starting from cat << EOF > rhel8stighigh.yaml and ending at EOF can be copy/paste into the CLI of a node with Parallelcluster installed. Ensure that you change the commented parameters to match your environment. 
cat << EOF > rhel8stighigh.yaml
Build:
  InstanceType: c5a.xlarge
  #this ParentImage is for Parallelcluster version 3.8. Ensure you type pcluster list-official-images on a machine that has parallelcluster installed to get the latest ami listings.
  ParentImage: ami-0d5ac0f6d75765b20
  ##Edit the below line with your subnet id
  SubnetId: YOUR_SUBNET_ID
  SecurityGroupIds: 
  #Edit the below line with your security group id
  - YOUR_SECURITY_GROUP_ID
  Components:
    - Type: arn
      Value: arn:aws-us-gov:imagebuilder:us-gov-west-1:aws:component/stig-build-linux-high/2023.4.0
  UpdateOsPackages:
    Enabled: true
EOF

#command to launch the pipeline from a machine with AWS Parallelcluster installed
pcluster build-image --image-configuration rhel8stighigh.yaml --image-id rhel8stighigh