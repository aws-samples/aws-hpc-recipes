# Getting started with RES-ready AMIs

## Info

This recipe builds out the following resources required to deploy a [RES-ready AMI](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html). The resources deployed include:

- [Image Builder role to access RES environment](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#prepare-role)
- [Linux and Windows Image Builder components](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#image-builder-component)
- [Image Builder Infrastructure](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#configure-ib-infrastructure)

Once deployed, end users will need to complete the following steps:

1. [Prepare Image Builder recipe](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#prepare-recipe)
2. [Configure Image Builder image pipeline](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#image-builder-pipeline)
3. [Run Image Builder image pipeline](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html#run-image-pipeline)

## Usage

This section includes details on the CloudFormation templates

- [`nested-imagebuilder-components.yaml`](assets/nested-imagebuilder-components.yaml) - Creates the Linux and Windows RES bootstrapping components
- [`imagebuilder-infrastructure.yaml`](assets/imagebuilder-infrastructure.yaml) - Creates the EC2 Image Builder infrastructure for the RES Environment
