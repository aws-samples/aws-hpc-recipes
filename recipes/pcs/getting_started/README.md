# Getting started with AWS PCS

## Info

This recipe supports the [_Getting started with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) section of the AWS PCS User Guide. 

## Usage

This section of the AWS PCS user guide contains references to several CloudFormation templates. Follow the directions in the tutorial to use them. 

Follow these links to inspect their source code:
* [`pcs-cluster-sg.yaml`](assets/pcs-cluster-sg.yaml) - Creates a cluster-wide security group for your PCS controller and attached nodes.
* [`pcs-iip-minimal.yaml`](assets/pcs-iip-minimal.yaml) - Creates a minimal IAM instance profile for your PCS compute node groups.
* [`pcs-lt-simple.yaml`](assets/pcs-lt-simple.yaml) - Creats a minimal launch template for PCS compute node groups.
* [`pcs-lt-efs-fsxl.yaml`](assets/pcs-lt-efs-fsxl.yaml) - Creates launch templates with a shared home (EFS) and high-speed storage filesystem (FSx for Lustre).

Feel free to use or adapt these basic templates for your own clusters.

