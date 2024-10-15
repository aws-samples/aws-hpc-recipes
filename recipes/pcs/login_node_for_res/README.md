# Creating a RES-ready AWS PCS login node

## Info

This recipe allows the creation of a [AWS Parallel Computing Service (PCS) login node](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_login-nodes_standalone.html) AMI compatible with [Research and Engineering Studio (RES)](https://github.com/aws/res). The Login Node AMI can be used in a RES as a software stack to submit HPC jobs to the PCS cluster.

## Assumptions

- RES deployment
- PCS deployment in the same VPC as RES
- An EFS or FSx for Lustre file system is shared between RES and PCS compute nodes

## Usage

### 1. Deploy components to build RES compatible PCS login node

You can launch this template by following this quick-create link: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=res-pcs-loginnode&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/login_node_for_res/assets/main.yml)

If you don't wish to use the quick-create link, you can also download the [assets/main.yml](assets/main.yml) file and upload it to [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation).

### 2. Build RES-ready PCS login node AMI

Follow the below steps outlined in [configure RES-ready AMI(s)](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html) to build the RES-ready AMI for a PC Login Node.

1. [Create ec2 Image Builder component](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#image-builder-component)
2. [Prepare your EC2 Image Builder recipe](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#prepare-recipe)
   1. Add the `res-pcs-login-node` component to the recipe. The following parameters are required:
      1. **Region:** <AWS Region for deployment - e.g. us-east-1>
      2. **ClusterId:** <PCS cluster id - e.g. pcs_axhof4inf9>
      3. **SlurmVersion:** <Slurm version - e.g. 23.11.9-1>
3. [Configure Image Builder image pipeline](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#image-builder-pipeline)
   1. The EC2 infrastructure configuration can be found in the Stack outputs from Step #1
4. [Run Image Builder image pipeline](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#run-image-pipeline)
5. [Register a new software stack in RES](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#register-res-ready-stack)

**Note**: The following components are built by this recipe:

- [IAM role](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#prepare-role) - Contains an additional policy to allow access to PCS resources.

### 3. Add PCS Security group to RES project

1. Create/Update a project in RES to add the required security group to allow VDI access to PCS cluster.

**Note:** This is the `PCSClusterSG` CloudFormation parameter security group provided in step #1

### 5. Launch Login node Virtual Desktop

Deploy a Virtual Desktop using the newly created/updated project and Software stack.

You now have a Virtual Desktop instance capable of submitting jobs to a PCS cluster!

![res_loginnode_vdi](docs/res_pcs_loginnode_vdi.gif)
