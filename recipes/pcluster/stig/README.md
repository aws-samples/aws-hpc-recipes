# Securing HPC on AWS: Implementing STIGs in AWS ParallelCluster


## Info

These instructions describe cloud native methods that HPC customers can use to aide their process of creating STIG compliant EC2 images for use within AWS Parallelcluster. Amazon EC2 Image Builder provides STIG hardening components to help you more efficiently build compliant images for baseline STIG standards. This can be used as part of an AWS Parallelcluster build image process. AWS Systems Manager provides a runbook, AWSEC2-ConfigureSTIG, which you can use to apply STIG settings to an EC2 instance. DISA develops and maintains STIGs and defines Severity Category Codes (CAT) which are referred to as CAT I, II, and III. AWS Parallelcluster instances that were put through the STIG hardening process had the STIG high settings applied. The list of applicable STIG settings that this translates to for Linux operating systems can be found about half way down [here](https://docs.aws.amazon.com/systems-manager-automation-runbooks/latest/userguide/awsec2-configurestig.html).

### RHEL8 and AL2 Instances with Internet Connectivity

1.	On a node that has [AWS Parallelcluster installed](https://docs.aws.amazon.com/parallelcluster/latest/ug/install-v3-parallelcluster.html), list the AWS Parallelcluster official images within your current AWS region by typing: pcluster list-official-images ![](images/Pcluster-List-Official-Images.PNG)

Note: If you get an error saying that the region is not set, type ‘aws configure’, press Enter twice, then type in your region – for customers operating in GovCloud West this would be us-gov-west-1. The full region listing can be found [here](https://docs.aws.amazon.com/general/latest/gr/rande.html). If typing ‘aws configure’ results in an error, this means that you need to install the AWS CLI on the instance. Instructions to install AWS CLI can be found [here](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html). 
    
2.	You will see a list of supported AWS Parallelcluster baseline images. For purposes of this walkthrough we will be using the RHEL8 x86_64 AMI which at the time of publication is ami-0d5ac0f6d75765b20. Note that this process is the same for Amazon Linux 2 which is marked as alinux2 in the output of the previous command. 
3.	Navigate to EC2 image builder in the AWS console and click on components. For filter-owner, select Amazon-managed and search for STIG. Recommend sorting by Creation time. Copy the ARN on the right hand side to your clipboard. For purposes of these instructions we will use arn:aws-us-gov:imagebuilder:us-gov-west-1:aws:component/stig-build-linux-high/2023.4.0 ![](images/EC2-Image-Builder-Components.PNG)
4.	On the same node that has AWS Parallelcluster installed, create a yaml file with the build image configurations matching the above parameters. Change the instance type, component arn, subnet ID, security group ID, and parent image to match your desired options. An example configuration file can be found [here](assets/rhel8stighigh.sh). Inputting a 'cat' command is as simple as copy/paste into the CLI. Just ensure you have changed the parameters for YOUR_SUBNET_ID and YOUR_SECURITY_GROUP_ID according to your environment. A picture of inputting these commands can be found [here](images/Cat-Command-and-Cluster-Launch.PNG).
5.	On the same EC2 instance, run the following command to trigger the CloudFormation build: pcluster build-image --image-configuration rhel8stighigh.yaml --image-id rhel8
6.	The process will take approximately 20-30 minutes to complete. You can type the following command to see when the build is completed: pcluster list-images --image-status AVAILABLE 

![](images/RHEL8-Build-Complete.PNG)

7. Once you have the resulting AMI (shown as amiId in the above picture) you can reference it inside your AWS Parallelcluster configuration file. An example file along with the command to create the cluster can be found [here](assets/example_parallelcluster.sh).

### RHEL8 and AL2 Instances without Internet Connectivity

Ensure that you have configured the [required VPC endpoints](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html) to allow connectivity from your private subnet to AWS Systems Manager. You will also need the [required VPC endpoints](https://docs.aws.amazon.com/parallelcluster/latest/ug/network-configuration-v3.html#aws-parallelcluster-in-a-single-public-subnet-no-internet-v3) for AWS Parallelcluster which will be used to launch your cluster with the resulting AMI.

1.	On a node that has [AWS Parallelcluster installed](https://docs.aws.amazon.com/parallelcluster/latest/ug/install-v3-parallelcluster.html), list the AWS Parallelcluster official images within your current AWS region by typing: pcluster list-official-images
2.	Using the same AMI from the previous example, we will utilize the RHEL8 x86_64 AMI which is ami-0d5ac0f6d75765b20 ![](images/Pcluster-List-Official-Images.PNG)
3.	Navigate to EC2 and click on Launch Instances. Under Application and OS Images (Amazon Machine Image) select Browse more AMIs. You will be taken to another page where you will then want to select Community AMIs. Once selected, search for the AMI that you want to launch. In this case I will be using ami-0d5ac0f6d75765b20. Select the instance and finish configuring its settings according to your environment. Once finished, launch the instance. ![](images/RHEL8-PCluster-AMI.PNG) 
4.	Next, navigate to Systems Manager and go to Run Command. Then select Run command on the top right. In the search bar, type in stig. Then select the level of STIG controls you want to apply. Then under Target selection, select the option for Choose instances manually and the instance you launched in the previous step. Output options are optional and can be turned off. Then select Run. ![](images/RHEL8-SSM-Run-Command.PNG)
5.	Once the command has successfully run, stop the EC2 instance and create an image from it. You can do this by selecting Actions->Images and Templates->Create image. Give the image a name and optionally a description, then click on Create image. ![](images/RHEL8-Create-Image.PNG)
6.	You can navigate to the AMIs section of the EC2 console to see the resulting AMI. This process will take around 5 minutes to change its status from Pending to Available. ![](images/RHEL8-AMI-Complete.PNG)
7.	Once you have the resulting AMI, you can reference it inside your AWS Parallelcluster configuration file. An example file along with the command to create the cluster can be found [here](assets/example_parallelcluster.sh).


### Ubuntu 20.04 Instances with or without Internet Connectivity

The process for Ubuntu 20.04 includes an extra step compared to RHEL8 and AL2 operating systems as there are a couple findings that Systems Manager cannot rectify during its run command. Due to this, we will launch an instance with a user data script that resolves findings [V-219166](https://www.stigviewer.com/stig/canonical_ubuntu_18.04_lts/2022-08-25/finding/V-219166), [V-238237](https://www.stigviewer.com/stig/canonical_ubuntu_20.04_lts/2023-09-08/finding/V-238237), and [V-238218](https://www.stigviewer.com/stig/canonical_ubuntu_20.04_lts/2021-03-23/finding/V-238218). There is only a minor difference in the process between environments with or without Internet connectivity. For instances without Internet connectivity, ensure that you have configured the [required VPC endpoints](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html) to allow connectivity from your private subnet to AWS Systems Manager, as well as the [required VPC endpoints](https://docs.aws.amazon.com/parallelcluster/latest/ug/network-configuration-v3.html#aws-parallelcluster-in-a-single-public-subnet-no-internet-v3) for AWS Parallelcluster. Users with Internet connectivity are not required to perform this step.

1.	On a node that has [AWS Parallelcluster installed](https://docs.aws.amazon.com/parallelcluster/latest/ug/install-v3-parallelcluster.html), list the AWS Parallelcluster official images within your current AWS region by typing: pcluster list-official-images
2.	We will utilize the Ubuntu 20.04 x86_64 AMI, which at the time of publication is ami-029778be256bd98dc ![](images/Pcluster-List-Official-Images.PNG)
3.	Navigate to EC2 and click on Launch Instances. Under Application and OS Images (Amazon Machine Image) select Browse more AMIs. You will be taken to another page where you will then want to select Community AMIs. Once selected, search for the AMI that you want to launch. In this case I will be using ami-029778be256bd98dc ![](images/Ubuntu-Base-AMI.PNG) Select the instance and finish configuring its settings according to your environment. Before you launch the instance, expand Advanced details and input the entirety of [Ubuntu STIG commands](assets/Ubuntu_STIG_Commands.sh) into the User data section at the bottom of the page. It should look similar to the below. Once this is complete, select Launch instance. ![](images/Ubuntu-User-Data-Script.PNG)
4.	Next, navigate to Systems Manager and go to Run Command. In the search bar, type in stig. Then select the level of STIG controls you want to apply. Then select the instance you want to run this command on, which should be the instance you launched in the previous step. Output options are optional and can be turned off. Then select Run. ![](images/Ubuntu-SSM-Run-Command.PNG)
5.	Once the command has successfully run, stop the EC2 instance and create an image from it. You can do this by selecting Actions->Images and Templates->Create image. Give the image a name and optionally a description, then click on Create image. ![](images/Ubuntu-Create-Image.PNG)
6.	You can navigate to the AMIs section of the EC2 console to see the resulting AMI. This process will take around 5 minutes to change its status from Pending to Available. ![](images/Ubuntu-AMI-Complete.PNG)
7.	Once you have the resulting AMI, you can reference it inside your AWS Parallelcluster configuration file. An example file along with the command to create the cluster can be found [here](assets/example_parallelcluster.sh). Be sure to match the operating system to Ubuntu. 


## Troubleshooting

1. If you are getting a ‘permission denied’ error after attempting to create a file using the cat command, ensure you are in writeable path. For purposes of this project, I am logged into the instance using systems manager, I then created a directory called hpc, and changed into that directory so my path is: /usr/bin/hpc
You can type whoami to see the currently logged in user. Then type ls -ld within the current directory to see who has permissions. You may see the following: drwxr-xr-x. 2 root root (date)
To change permissions on a folder, again using ssm-user as an example, we can type the following to change permissions on a folder: sudo chown ssm-user:ssm-user /usr/bin/hpc
Once this is changed, you should be able to run the cat command successfully.
2. If you get an error saying "Unable to find node executable" you can perform the following the command, "nvm install --lts=Gallium". If this doesn't work, perform the following series of commands

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash

chmod ug+x ~/.nvm/nvm.sh

source ~/.nvm/nvm.sh

nvm install --lts

node --version

For users without Internet connectivity, you will want to pre position the current Node tar file into an S3 bucket and copy it over using 'aws s3 cp' AWS CLI command. The most up to date versions can be found [here](https://nodejs.org/en/download). You will want to select the Linux Binaries (x64) option to download. 
The following is an example that can be run from the EC2 instance: 

aws s3 cp s3://(your_S3_bucket)/node-v20.10.0-linux-x64.tar.xz /tmp/

tar -xJf /tmp/node-v20.10.0-linux-x64.tar.xz -C /usr/local --strip-components=1

3. For users with Internet connectivity, if your build is failing ensure that the subnet you are launching into actually has Internet access. You can launch a test EC2 instance in the same subnet and security group as your configuration file to check. Common issues can be that your public subnet may not be auto assigning public IPv4 addresses (https://docs.aws.amazon.com/vpc/latest/userguide/modify-subnets.html#subnet-public-ip), or your private subnet may not be properly configured to leverage a NAT device via routing.