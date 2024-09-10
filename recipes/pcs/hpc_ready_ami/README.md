# HPC-ready AMIs

## Info

This recipe is designed to support you building your own AMIs to use with AWS PCS. 

It contains three types of resource:
1. Scripts 
2. [EC2 ImageBuilder](https://docs.aws.amazon.com/imagebuilder/latest/userguide/what-is-image-builder.html) assets
3. [HashiCorp Packer](https://www.packer.io/) resources

## Usage

You can use these resources as-is, fork the repository and adapt them to your own needs, or contibute your own knowledge and AMI management code back to HPC recipes. You can also, of course, just read them over to learn how other people are building AMIs for PCS.

### Scripts

In the [scripts](assets/scripts/) directory, you will find a growing number of scripts that can be used to install and/or configure software on an AMI. The scripts are designed to support the same operating system distributions and versions as AWS PCS (currently: Amazon Linux 2, RHEL 9, Rocky Linux 9, and Ubuntu 22.04). 

They're organized around using a shared Bash [script](assets/scripts/common.sh) to detect the operating system distribution, version, and architecture. This makes them extensible in the future, and straightforward to reason about and debug.

Some scripts accept parameters that control their installation or configuration behavior. For example, [`install-spack.sh`](assets/scripts/install-spack.sh) allows you to specify the destination where Spack will be installed. 

You can incorporate these scripts into your own processes. They are available for download via HPC Recipes public URLs, as described below. 

### EC2 ImageBuilder Assets

We provide CloudFormation templates that let you create EC2 ImageBuilder components that use the HPC-ready AMI scripts. They can be found in the [components](assets/components/) directory. The Image Builder component filename maps 1:1 to the name of the script. 

For example, the file [install-ssm-agent.yaml](assets/components/install-ssm-agent.yaml) can create an Image Builder component named `SsmAgentInstaller` that uses the [install-ssm-agent.sh](assets/scripts/install-ssm-agent.sh) to install [SSM Agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html) on the AMI. 

The ImageBuilder components are available as individual templates that deploy a CloudFormation stack. There is also a [meta-template](assets/imagebuilder-components.yaml) that will create all available ImageBuilder components at once, using nested CloudFormation stacks. 

#### Deploy all ImageBuilder components [recommended]

1. Navigate to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation)
2. Choose **Create stack**, then upload [imagebuilder-components.yaml](assets/imagebuilder-components.yaml) as the template. 
3. In Parameters:
    * For **HpcRecipesS3Bucket** choose the HPC Recipes bucket where the component is hosted. Unless you are working with a pre-release version of HPC Recipes for AWS, this will be `aws-hpc-recipes`.
    * For **HpcRecipesBranch**, enter the release branch for the HPC Recipes bucket. Unless you are working with a pre-release version of HPC Recipes for AWS, this will be `main`.
4. Finish creating the stack. 
5. When the stack's status reaches `CREATE_COMPLETE`, navigate to the [EC2 Image Builder console](https://console.aws.amazon.com/imagebuilder/home#/components).
    * On the **Components** page, choose **Onwed by me**. Your new ImageBuilder components should be available there. 

#### Deploy a single ImageBuilder component

1. Choose one of the YAML file templates in the [components](assets/components/) directory
2. Navigate to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation)
3. Choose **Create stack**, then upload the YAML file you have chosen
4. In Parameters:
    * For **HpcRecipesS3Bucket** choose the HPC Recipes bucket where the component is hosted. Unless you are working with a pre-release version of HPC Recipes for AWS, this will be `aws-hpc-recipes`.
    * For **HpcRecipesBranch**, enter the release branch for the HPC Recipes bucket. Unless you are working with a pre-release version of HPC Recipes for AWS, this will be `main`.
5. Finish creating the stack. When its status reaches `CREATE_COMPLETE`, navigate to the [EC2 Image Builder console](https://console.aws.amazon.com/imagebuilder/home#/components).
    * On the **Components** page, choose **Onwed by me**. Your new ImageBuilder component should be avilable there. 

#### Build an AMI using your ImageBuilder components

_Coming soon._

#### Use the example all-in-one ImageBuilder template

_Coming soon._

### HashiCorp Packer resources

Logic for each ImageBuilder component is kept in standalone scripts. This adds a little complexity to the development process, but means we have a source of truth for AMI management actions that is agnostic to the build platform being used. To demonstrate this, we include a template that can be used with HashiCorp Packer. 

#### Use the Packer template to build an Amazon Linux 2 AMI

The template is configured to support building an Amazon Linux 2 AMI. To use it:

1. Identify a source Amazon Linux 2 AMI ID for the region where you will build your AMI
2. Build an AMI using this command:

```shell
packer build \
  -var "aws_region=us-east-2" \
  template.json
```

Substitute in **us-east-2** for the region name where you will build your AMI. If you are using a pre-release version of HPC Recipes, set values for `hpc_recipes_s3_bucket` and `hpc_recipes_s3_branch`. 

#### Use the Packer template and a support script to build an alternative distro

1. Download the [support script](assets/packer/set_variables.sh) and the [template](assets/packer/template.json) to the same directory. Make the support script executable (`chmod a+x set_variables.sh`).
2. Select the correct distro identifier for your build environment. At present, your choices are:
    * `amzn_2`
    * `rhel_9`
    * `rocky_9`
    * `ubuntu_22_04`
3. Identify a source Ubuntu 22.04 AMI ID for the region where you will build your AMI
4. Build your AMI with command similar to this:

```shell
packer build \
  -var "aws_region=us-east-2" \
  -var "source_ami=UBUNTU-SOURCE-AMI-ID" \
  -var-file <(./set_variables.sh ubuntu_22_04) \
  template.json
```

The support script sets the correct SSH username and root device name for an Ubuntu-based operating system. It continues to assume you prefer to build an x86-based AMI. You might want to build for Graviton. To do so, provide an alternative instance type. Also, make sure your source AMI is Graviton-compatible. 

```shell
packer build \
  -var "aws_region=us-east-2" \
  -var "source_ami=ARM64-UBUNTU-SOURCE-AMI-ID" \
  -var-file <(./set_variables.sh ubuntu_22_04) \
  -var "instance_type=c7g.8xlarge" \
  template.json
```

#### Use pre-release versions of HPC Recipes

You can point the Packer template to alternative versions of HPC Recipes. To do so, pass the relevant bucket name and release branch, as demonstrated here. For more information on this topic, see _HPC Recipes public URLs_ below. 

```shell
packer % packer build \
  -var "hpc_recipes_s3_bucket=aws-hpc-recipes-dev" \
  -var "hpc_recipes_branch=testbranch" \
  -var-file <(./set_variables.sh amzn_2) \
  template.json
```

### HPC Recipes public URLs

Assets directories from recipes in the `main` branch of HPC Recipes for AWS are mirrored to a public AWS S3 bucket. This means they can be accessed directly, using a browser or CLI tool like `wget`. 

Here is an example of fetching the `update-os.sh` script from this recipe from the main HPC recipes bucket.

```shell
curl -fsSL "https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/hpc_ready_ami/assets/scripts/update-os.sh" -o "update-os.sh"
```

Pre-release builds of HPC Recipes are maintained in branches. Their assets are published to an alternative bucket `aws-hpc-recipes-dev` under the name of their git branch. Here is an example of fetching `update-os.sh` from a branch named `testbranch`.

```shell
curl -fsSL "https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/testbranch/recipes/pcs/hpc_ready_ami/assets/scripts/update-os.sh" -o "update-os.sh"
```

The CloudFormation templates that deploy EC2 ImageBuilder components for this recipe have two parameters that can be set to direct them to pre-release HPC Recipes builds:

* **HpcRecipesS3Bucket** - either `aws-hpc-recipes` or `aws-hpc-recipes-dev`
* **HpcRecipesBranch** - either `main` or whatever branch name you or your collaborators are working on

The Packer templates accept similar parameters:

* **hpc_recipes_s3_bucket** - either `aws-hpc-recipes` or `aws-hpc-recipes-dev`
* **hpc_recipes_branch** - either `main` or whatever branch name you or your collaborators are working on

Note that while the `aws-hpc-recipes-dev` is a stable resource, any directories within it may be deleted or changed at any time. It is strictly for testing out pre-release recipe assets. 

## Road Map

Here are some near-future improvements we have planned:

1. Add support for installing NVIDIA drivers
2. Add support for installing CUDA
3. Add support for creating a custom Spack environment 
5. Add support for installing Pyxis and enroot
6. Add support for installing AppTainer

A little further in the future, this recipe will (probably) become a standalone repository, with a different release cadence from HPC Recipes for AWS. 

## Contributing

