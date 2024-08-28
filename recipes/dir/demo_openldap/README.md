# Demo OpenLDAP on ECS

## Info

This recipes sets up a simple OpenLDAP service on Amazon Elastic Container Service (Amazon ECS) that can support multi-user HPC resources.

**Note** This template is for educational purposes only because it does not enable encrypted LDAP.

## Usage

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=openldap-on-ecs&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_openldap/assets/main.yaml)
2. Follow the instructions in the AWS CloudFormation console
    a. Set the domain name (and optional subdomain)
    b. Provide a strong administrator password
    c. Select a username for the bind user
    d. Provide a strong password for the bind user
    e. Create an example OpenLDAP user by setting UserName and UserPassword
    f. Choose the VPC and subnets where your LDAP service will be created. 
3. Monitor the status of the stack. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. You will find several values you can use to create a HPC resources that work with LDAP.

### Outputs

This stack has the following outputs which can be used with other deployments:

* `DomainAddrLdap` - LDAP URL where the server may be accessed
* `DomainComponents` - Domain name expressed as components. Useful for setting LDAP search base.
* `DomainName` - FQDN for the OpenLDAP domain server. 
* `DomainShortName` - Capitalized version of the first element in the FQDN
* `DomainServiceAccount` - Read-only bind account for the server
* `PasswordSecretArn` - AWS Secrets Manager ARN where the bind password is stored

## User and Group Management 

Unlike the Managed AD example, there is no support in this stack for managing additional users. You can log in using the admin, bind, and example users created by the stac.

## LDIF Support

Unlike the Managed AD example, there is no support for a custom LDIF file. 

## Cost Estimate

It will cost approximately $20.00 to run this OpenLDAP service for a week. 

## Cleaning Up

When you are done using this resource, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
