# Amazon FSx for NetApp ONTAP File System

## Info

This recipe demonstrates how to use CloudFormation to deploy an Amazon FSx for NetApp ONTAP file system. It includes optional configuration to join to an Active Directory and create a CIFS file share.

## Usage

### Prerequisites

Before deploying this template, ensure you have:
1. A VPC with at least 1 private or public subnet
2. (Optional) An Active Directory setup if you plan to join the FSx file system to your AD domain

### Template Features

The template provides:
- FSx for ONTAP file system deployment
- Storage Virtual Machine (SVM) creation
- Volume creation
- Automated FSx admin password generation and secure storage in AWS Secrets Manager
- Optional CIFS share configuration through a temporary EC2 instance
- IAM roles and security configurations

### Deployment Components

The template creates:
1. An FSx for ONTAP file system
2. A secret in AWS Secrets Manager for the FSx admin password (when CIFS share creation is enabled)
3. A temporary EC2 instance for administrative tasks (when CIFS share creation is enabled)
4. Required IAM roles and instance profiles
5. Security groups for file system access
6. Optional CIFS share configuration

### Create a FSx for NetApp ONTAP file system

* Create a [Single AZ FSx for NetApp ONTAP file system](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=fsx-ontap&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_ontap/assets/main.yaml)

When prompted to choose a VPC and subnet, select the one where you intend to place the majority of your computing. It is possible to access FSx for NetApp ONTAP file systems across Availability Zones, but there will be higher latency and additional costs due to cross-zone traffic.

An existing security group may be provided, and while NFS traffic must be allowed if only using Linux instances, be aware of the necessary [networking configuration requirements](https://docs.aws.amazon.com/fsx/latest/ONTAPGuide/self-manage-prereqs.html#ontap-ad-network-configs) for FSx for NetApp ONTAP if you additionally plan to join your file system to Active Directory and use SMB traffic for Windows instances.

## Example Usage

To mount the NetApp ONTAP volume on **Linux instances**:

1. Create a directory on your Amazon EC2 instance to use as the volume's mount point with the following command. In the following example, replace `mount-point` with your own information.
`sudo mkdir /mount-point`
2. Mount your Amazon FSx for NetApp ONTAP file system to the directory that you created.
* `nfs_version` – The NFS version you are using; FSx for ONTAP supports versions 3, 4.0, 4.1, and 4.2.
* `nfs-dns-name` – The NFS DNS name of the storage virtual machine (SVM) in which the volume you are mounting exists. You can find the NFS DNS name in the Amazon FSx console by choosing **Storage virtual machines**, then choosing the SVM on which the volume you are mounting exists. The NFS DNS name is found on the **Endpoints** panel.
* `volume-junction-path` – The junction path of the volume that you're mounting. You can find a volume's junction path in the Amazon FSx console on the **Summary** panel of the Volume details page.
* `mount-point` – The name of the directory that you created on your EC2 instance for the volume's mount point.

`sudo mount -t nfs -o nfsvers=nfs_version nfs-dns-name:/volume-junction-path /mount-point`

For **Windows instances** using CIFS shares (if configured):

1. Open a command prompt.
2. Run the following command. Replace the following:
* Replace `Z:` with any available drive letter.
* Replace `DNS_NAME` with the DNS name or the IP address of the SMB endpoint for the volume's Storage Virtual Machine (SVM).
* Replace `CIFSShareName` with the name of your specified SMB CIFS file share name.

`net use Z: \\DNS_NAME\CIFSShareName`

## Cost Estimate

The cost to operate an FSx for NetApp ONTAP file system varies based on several factors:
- Storage type and capacity (SSD or capacity pool storage)
- Deployment type (Single-AZ or Multi-AZ)
- Provisioned IOPS
- Throughput capacity
- Backup storage
- Data transfer costs between AZs or Regions

For detailed pricing information and to calculate your estimated costs, please visit the AWS pricing page for FSx for NetApp ONTAP.

For reference with currrent pricing (February 2025), a 1 TB, 384 MBps, 3,072 IOPS Single AZ FSx for ONTAP file system will cost around $400 to operate for a month (excluding any backups).

## Cleaning Up

Ensure all data is backed up before deletion as the cleanup process is irreversible.

To remove all resources:
1. Delete any additional volumes or shares you may have created in your file system.
2. Delete the CloudFormation stack.
3. Verify all associated resources are properly cleaned up.
