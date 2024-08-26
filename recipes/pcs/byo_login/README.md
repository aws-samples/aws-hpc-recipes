# Bring your own login node to AWS PCS

## Info

This recipe contains assets to help you implement the recommendations in [_Using standalone instances as AWS PCS login nodes_](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_login-nodes_standalone.html) in the AWS PCS user guide.

## Usage

Several files in the [`assets`](assets/) directory will be of use.

* `slurm-23.11-sackd.service` - You can use this template file to create the required `sackd` systemd service. 
