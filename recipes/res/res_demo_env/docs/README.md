# Research and Engineering Studio (RES) further documentation

## Info

This is further documentation about how to use the cloud resources created by this template.

## "Batteries Included" resources

The "Batteries Included" template (aka `bi.yaml`) install the required network resources needed to support the Research And Engineering Studio (RES) environment. This allows a customer to stand up sample resources to hook into the RES environment for evaluation purposes.

The resources that the `bi.yaml` template creates are:

 1. Networking ([link](../../../net/hpc_large_scale/README.md)): A template that sets up networking resources such as security groups, internet gateway, and subnets inside a VPC
 2. Managed Directory ([link](../../../dir/demo_managed_ad/README.md)): A template deploys a basic AWS Managed Microsoft Active Directory using a [LDIF](../assets/res.ldif) file to create users and groups
 3. Storage ([link](../../../storage/efs_simple/README.md)): A template that sets up an EFS file system that acts as a shared drive for RES desktop sessions to use; each user gets their own home subfolder
 4. Certs ([link](../../../security/public_certs/README.md)): A template that creates public certificates to use with Amazon Route53 owned domains
 5. Windows Management Service ([link](../../../dir/demo_managed_ad/assets/windows_management_host.yaml)): A template for launching Microsoft Windows Management Hosts into a subnet

## Launch a full RES stack

In order to launch an entire cloud stack for a RES environment you can [launch a full RES stack](full_stack_usage.md). This will launch a cloud stack that includes the "Batteries Included" (`bi.yaml`) script then it automatically uses those outputs to install the Research And Engineering Studio (`ResearchAndEngineeringStudio.json`) template. 

There are a number of RES template stack inputs that can be taken right from the `bi.yaml` root stack Outputs:
 - EnvironmentName
 - ActiveDirectoryName
 - ADShortName
 - LDAPBase
 - LDAPConnectionURI
 - UsersOU
 - GroupsOU
 - SudoersOU
 - SudoersGroupName
 - ComputersOU
 - SharedHomeFilesystemId
 - ACMCertificateARNforWebApp
 - CertificateSecretARNforVDI
 - PrivateKeySecretARNforVDI

The pull down input parameters are:
 - VpcId
 - PrivateSubnets
 - PublicSubnets

These become automatically populated in the drop downs.

These input parameters have to be manually added:
 - ServiceAccountUsername: for a `bi.yaml` created environment this will be `admin`
 - CustomDomainNameforWebApp: this comes from Route53's subdomains such as `web.person.people.aws.dev`
 - CustomDomainNameforVDI: this comes from Route53's subdomains such as `vdc.person.people.aws.dev`

## Learn how to manage Users and Groups

This is a small tutorial for managing Active Directory (AD) users and groups. 

- [Learn how to manage Users and Groups](users_and_groups.md)
- The Managed AD had further instructions [here](../../../dir/demo_managed_ad/README.md)

## Some common issues and debugging techniques with the `bi.yaml` template

These are some of the common issues when using the `bi.yaml` template.

## The console log files

The log files to examine in the instances will be:
 - `/var/log/user-data.log`
 - `/var/log/cfn-init-cmd.log`
 - `/var/log/cfn-init.log`
 - `/var/log/cfn-wire.log`

 For further information, see the [CloudFormation Logs](https://aws.amazon.com/blogs/devops/view-cloudformation-logs-in-the-console/) post.

### Poor AD passwords

The passwords must meet password complexity requirements from the default AD [policy](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements).
