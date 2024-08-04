# Using EFA with AWS PCS

## Info

This recipe contains assets to support using Elastic Fabric Adapter (EFA) with AWS PCS.

## Usage

Download or access the AWS PCS User Guide. Go to _Using Elastic Fabric Adapter with AWS PCS_ for . Follow the directions. Whenever you encounter links to AWS CloudFormation assets, you can find their source code in the `assets` directory of this recipe.

* `efa-sg.yaml` - Creates a self-referencing security group for EFA network interfaces.
* `efa-placement-group.yaml` - Creates a cluster placement group for EFA-enabled instances.
* `pcs-lt-efa.yaml` - All-in-one template to create an EFA-enabled security group, placement group, and launch template for instances with up to 4 network cards. 
