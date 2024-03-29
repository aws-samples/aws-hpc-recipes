# Research and Engineering Studio (RES) on AWS demo environment

## Info

This recipe uses a CloudFormation stack to launch a non-production installation of [Research and Engineering Studio (RES) on AWS](https://aws.amazon.com/hpc/res/) that you can use to try it out. It also includes a CloudFormation stack that can be used standalone to launch just the supporting infrastructure for RES (networking, directory service, storage, etc.)

### Updates, fixes, and new features

### Launch RES
* Feb 08, 2024 - You now have the option to configure the throughput mode for the underlying EFS file system that acts as the shared drive for RES desktop sessions. Use the default value of `bursting` to help prevent cost overrun.
* Feb 07, 2024 - The AD admin hosts now automatically shut down after launch to reduce costs.
* Feb 04, 2024 - You can now restrict inbound access to your RES environment and its Windows administrative hosts using a managed VPC Prefix List. This is especially helpful for cases where a corporate VPN you are targeting spans many CIDR blocks. 

## Launch RES

1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch RES.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=resdemostack&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/res/res_demo_env/assets/res-demo-stack.yaml)
3. Follow the instructions in the AWS CloudFormation console. 
4. Monitor the status of the stack named **resdemostack**. When its status is `CREATE_COMPLETE`, check your email for a message with the subject line **Invitation to Join RES Environment**. Follow the instructions you find there to log in as `clusteradmin` and change your password.
5. Follow the steps in the RES [Configuration guide] to set up SSO so that demonstration accounts and groups can log into the system

![welcome-email](docs/welcome.png)

### Optional: Exploring the CloudFormation resources

RES is deployed using interconnecting CloudFormation stacks. Here is an example of a RES deployment in a clean AWS account. 

![stacks](docs/stacks.png)

The main stack, launched by the demo template above is named *demostack8* (**a** in the figure). It in turn launches several child stacks. Each of those is named *demostack8-ResourceName* (**b**). One of those resources is named *demostack8-RES-Identifier*. This is the actual RES application stack. It deploy several child stacks of its own, named *res-demo-ModuleName* after the RES environment name (**c**).

## RES External Resources stack

RES has several infrastructure depdendencies, such as networking, a directory service, EFS volumes, and management instances. The demo recipe above creates them using the RES External Resources template. You can use that stack directly to create a foundation upon which to install RES. Learn more about its features and usage in the [docs](docs/README.md).

## Cleaning Up

When you are done using these resources, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack(s). If you have enabled termination protection, you will need to disable it first. Consult the [AWS CloudFormation User Guide](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/Welcome.html) for more details.

