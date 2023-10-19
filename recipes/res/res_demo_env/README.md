# Research and Engineering Studio (RES) demo cloud resources

## Info

Demonstration environment for RES on AWS. This recipe will create a number of external resources that will be used in the Research and Engineering Studio Environment.

## Usage

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=res-bi&templateURL=https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/res/recipes/res/res_demo_env/assets/bi.yaml)

### Parameters (Inputs)

As parameters to the automated stack:

* `DomainName` - This is the domain for the Active Directory (AD). The value `corp.res.com` corresponds to the domain that is used in the supplied LDIF file which sets up bootstrap users, so if you would like to use default users this needs remain as-is. Otherwise, you may change it (and provide a separate LDIF file). This doesn't need to match the domain used for AD.
* `AdminPassword` - This is the password for an AD administrator (username `admin`). This user is created in the AD for administration purposes and isn’t used beyond the initial bootstrapping phase. Note that both this password and ServiceAccountPassword must meet password complexity requirements from the default AD [policy](https://learn.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements).
* `ServiceAccountPassword` - This is the password used to create a service account that is used for synchronization.
* `Keypair` - This EC2 key pair is used to connect to the administrative instances.
* `LDIFS3Path` - This is an S3 path to an LDIF file that is imported during the bootstrapping phase of setting up the AD. For further information about the LDIF file see [here](https://github.com/aws-samples/aws-hpc-recipes/blob/main/recipes/dir/demo_managed_ad/README.md#ldif-support). This parameter is pre-populated with a file that creates a number of users in the AD.
* `ClientIpCidr` - This should be the IP address that you will be accessing the site from. For instance, navigate to whatsmyip.org, select your IP address and use `[IPADDRESS]/32` to only allow access from your host.
* `EnvironmentName` - If the PortalDomainName is provided, this name is used to add tags to the secrets that are generated so that they can be used within the environment. This will need to match the EnvironmentName parameter that is used when creating the RES stack later.
* `PortalDomainName` - This is the value of a domain that exists in Route53 on the account. If this is provided, then a public certificate (and key file) will be generated and uploaded to Secrets Manager. If you have your own domain and certificates, this parameter (and the EnvironmentName) can be left blank.

### Outputs

The outputs from this automated stack are:

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
- `RootUserName` - The username for a service account that is used to connect to AD. Note that this account must have access to create computers. (e.g. `ServiceAccount` or `admin`)
- `SharedHomeFilesystemId` - An EFS Id to use for the shared home filesystem for Linux VDI hosts (e.g. `fs-041b7c1bd27f0c38e`)
- `SudoersOU` - The OU for users who should have sudoers permission across all projects. The value provided here is based off of a supplied LDIF file. (e.g. `OU=Users,OU=RES,OU=corp,DC=corp,DC=res,DC=com`)
- `UsersOU` - The OU for all users who might join the system. The value provided here is based off of a supplied LDIF file. (e.g. `OU=Users,OU=RES,OU=corp,DC=corp,DC=res,DC=com`)
- `VpcId` - The Virtual Private C that the network resources have been created. (e.g. `vpc-011439ed80a3e6a3f`)

## Cost Estimate

