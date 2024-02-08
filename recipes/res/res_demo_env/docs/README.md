# Research and Engineering Studio (RES) External Resources Documentation

You can launch a stack that sets up External Resources for RES by clicking [this link](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=resexternal&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/res/res_demo_env/assets/bi.yaml). After it has launched, you can deploy RES using its resources. See the RES [User Guide](https://docs.aws.amazon.com/res/latest/ug/deploy-the-product.html) for details.

## Info

This template installs networked resources needed to support a Research And Engineering Studio (RES) environment for evaluation purposes. It creates the following resources, using other HPC Recipes:
 1. Networking ([link](../../../net/hpc_large_scale/README.md)): A template that sets up networking resources such as security groups, internet gateway, and subnets inside a VPC
 2. Managed Directory ([link](../../../dir/demo_managed_ad/README.md)): A template that deploys a basic AWS Managed Microsoft Active Directory using a [LDIF](../assets/res.ldif) file to create users and groups
 3. Storage ([link](../../../storage/efs_simple/README.md)): A template that sets up an EFS file system that acts as a shared drive for RES desktop sessions to use; each user gets their own home subfolder
 4. Certificates ([link](../../../security/public_certs/README.md)): A template that creates public certificates to use with Amazon Route53 owned domains
 5. Windows Management Host ([link](../../../dir/demo_managed_ad/assets/windows_management_host.yaml)): A template for launching Microsoft Windows Management Hosts into a subnet

## Parameter and Output Reference

The template accepts the following Parameters:
* `DomainName` - This is the domain for the Active Directory (AD). The value `corp.res.com` corresponds to the domain that is used in the supplied LDIF file which sets up bootstrap users, so if you would like to use default users this needs remain as-is. Otherwise, you may change it (and provide a separate LDIF file). This doesn't need to match the domain used for AD.
* `AdminPassword` - This is the password for an AD administrator (username `admin`). This user is created in the AD for administration purposes and isn’t used beyond the initial bootstrapping phase. Note that both this password and ServiceAccountPassword must meet password complexity requirements from the default AD [policy](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements).
* `ServiceAccountPassword` - This is the password used to create a service account that is used for synchronization.
* `Keypair` - This EC2 key pair is used to connect to the administrative instances.
* `DemoUserNameInAd` - Username for a demo user created in AD
* `DemoUserPasswordInAd` - Password for demo user
* `DemoAdminInAd` - Username for a demo admin created in AD
* `DemoAdminPasswordInAd` - Password for demo admin
* `LDIFS3Path` - This is an S3 path to an LDIF file that is imported during the bootstrapping phase of setting up the AD. For further information about the LDIF file see [here](https://github.com/aws-samples/aws-hpc-recipes/blob/main/recipes/dir/demo_managed_ad/README.md#ldif-support). This parameter is pre-populated with a file that creates a number of users in the AD. The default LDIF file demonstrates use of variable substitution for OU, DC, bind user, and the demo accounts. 
* `ClientIpCidr` - The IP address (or range) that you will be accessing the AD admin hosts from. For instance, navigate to whatsmyip.org, select your IP address and use `[IPADDRESS]/32` to only allow access from your host.
* `ClientPrefixList` - A managed VPC Prefix list defining hosts you can access the Windows AD admin host from. 
* `EnvironmentName` - If the PortalDomainName is provided, this name is used to add tags to the secrets that are generated so that they can be used within the environment. This will need to match the EnvironmentName parameter that is used when creating the RES stack later.
* `PortalDomainName` - This is the value of a domain that exists in Route53 on the account. If this is provided, then a public certificate (and key file) will be generated and uploaded to Secrets Manager. If you have your own domain and certificates, this parameter (and the EnvironmentName) can be left blank.
* `ClientPrefixList` - A prefix list that will be used to provide access to the AD management nodes. (This resource type can be managed in https://console.aws.amazon.com/vpcconsole/home#ManagedPrefixLists)
* `EFSThroughputMode` - The throughput mode for the EFS file system. This can be either `bursting` or `elastic`. 


The template creates the following Outputs:
- `ActiveDirectoryName` - Fully Qualified Domain Name (FQDN) for your Active Directory such as (e.g. `corp.res.com`)
- `ADShortName` - The short name in Active Directory (e.g. `CORP`)
- `CertificateSecretArn` - ARN for a secret that contains the generated certificate. (e.g. `arn:aws:secretsmanager:us-east-1:111111111111:secret:Certificate-res-bi-aaja-Certs-O54JDHVEGGGG-RNsium`)
- `ComputersOU` - The OU for computers that join the AD. The value provided here is based off of a supplied LDIF file. (e.g. `OU=Computers,OU=RES,OU=corp,DC=corp,DC=res,DC=com`)
- `EnvironmentName` - Name of Research and Engineering Studio environment. (e.g. `res-env`)
- `GroupsOU` - The OU for groups that users belong to who might join the system. The value provided here is based off of a supplied LDIF file. (e.g. `OU=Users,OU=RES,OU=corp,DC=corp,DC=res,DC=com`)
- `Keypair` - Key pair used for management instances (e.g. `id_edsa`)
- `LDAPBase` - The Base DN is the starting point an LDAP server uses when searching for users authentication. (e.g. `CORP`)
- `LDAPConnectionURI` - An ldap:// path that can be reached from the hosts that hosts the Active Directory server. (e.g. `ldap://10.3.152.17`)
- `LDAPSConnectionURI` - The secure connection to the LDAP (e.g. `ldaps://corp.res.com`)
- `PrivateKeySecretArn` -  If you use a public domain for your web portal, this is the ARN to a secret that stores the private key for your certificate. (e.g. `arn:aws:secretsmanager:us-east-1:111111111111:secret:PrivateKey-res-bi-aaja-Certs-O54JDHVEGGGG-d4skqx`)
- `PrivateSubnets` - Subnets in different AZs where the infrastructure hosts will be launched (e.g. `subnet-087e569358aa1e42e,subnet-01e71d067188634bc,subnet-06e98217b3d18efaa`)
- `PublicSubnets` -  Subnets in different AZs where the VDI instances will be launched (e.g. `subnet-009aef6594f358444,subnet-0bc368105f9eee1ec,subnet-07155ac2d0b74b78c`)
- `ServiceAccountUsername` - The username for a service account that is used to connect to AD. Note that this account must have access to create computers. (e.g. `ServiceAccount` or `Admin`)
- `SharedHomeFilesystemId` - An EFS Id to use for the shared home filesystem for Linux VDI hosts (e.g. `fs-041b7c1bd27f0c38e`)
- `SudoersOU` - The OU for users who should have sudoers permission across all projects. The value provided here is based off of a supplied LDIF file. (e.g. `OU=Users,OU=RES,OU=corp,DC=corp,DC=res,DC=com`)
- `UsersOU` - The OU for all users who might join the system. The value provided here is based off of a supplied LDIF file. (e.g. `OU=Users,OU=RES,OU=corp,DC=corp,DC=res,DC=com`)
- `VpcId` - The Virtual Private Cloud where the network resources have been created. (e.g. `vpc-011439ed80a3e6a3f`)

Several of these outputs can be used as inputs into the RES template stack.
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

You can also use the VPC and subnets from the external resource stack. They are found in outputs named:
 - VpcId
 - PrivateSubnets
 - PublicSubnets

## Learn how to manage Users and Groups

Consult the RES documentation and the documentation for [AWS Managed Microsoft AD](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/directory_microsoft_ad.html) for in-depth guidance on user and group management with AD. To get started, you can review the short tutorial included in this recipe. 
- [Learn how to manage Users and Groups](users_and_groups.md)
- The Managed AD HPC Recipe has further instructions [here](../../../dir/demo_managed_ad/README.md)
