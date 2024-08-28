# Using EFA with AWS PCS

## Info

This recipe helps you implement the recommendations in [_Using Elastic Fabric Adapter (EFA) with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_networking_efa.html) in the AWS PCS user guide.

## Usage

This section of the AWS PCS user guide contains references to several CloudFormation templates. Follow the directions in the user guide to use them. 

Follow these links to inspect their source code:
* [`efa-sg.yaml`](assets/efa-sg.yaml) - Creates a self-referencing security group for EFA network interfaces.
* [`efa-placement-group.yaml`](assets/efa-placement-group.yaml) - Creates a cluster placement group for EFA-enabled instances.
* [`pcs-lt-efa.yaml`](assets/pcs-lt-efa.yaml) - All-in-one template to create an EFA-enabled security group, placement group, and launch template for instances. Supports up to 4 network cards.

Feel free to use or adapt these basic templates for your own clusters.
