# Multi-user PCS Compute Node Groups

## Info

This recipe provides a pattern you can extend to build multi-user compute node groups with PCS, powered by a directory service with an LDAP interface. Examples for AWS Managed Microsoft AD and a self-hosted OpenLDAP server running on Amazon ECS are provided. It should be possible to extend the designs shown here to most directory service providers. Contributions are welcome!

**Note** The code samples included here should not be used for anything beyond demonstration or training purposes, as they configures LDAP without TLS encryption.

## Usage

### (Optional) Deploy an HPC networking stack

1. Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy HPC recipes clusters in. If you named the networking stack something besides **hpc-networking**, make a note of that as we refer to your networking stack by name in some other recipes. 

### Deploy an LDAP server

This recipe includes templates for launching multiple directory servers. You can have more than one running at once. This can be helpful if you are evaluating multiple approaches.

* Deploy [AWS Managed Microsoft AD](docs/managed-ad.md)
* Deploy [OpenLDAP on Amazon ECS](docs/openldap-ecs.md)

Each LDAP service recipe will leave you with the following outputs. Note their values so you can configure your PCS compute node groups.

* `DomainName` - Fully qualified domain name for the directory server
* `DomainShortName` - Short name for the directory server
* `DomainComponents` - Domain name expressed as components (dc=)
* `DomainAddrLdap` - LDAP address for the server
* `DomainServiceAccount` - Bind account for the directory server
* `PasswordSecretArn` - Secrets manager ARN storing the bind password
* `AdminPasswordSecretArn` - Secrets manager ARN storing the password for the adminstrative (`Admin`) user

### Deploy a Compute Node Group
