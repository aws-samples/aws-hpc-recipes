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

**Note** Record the sample username and password you provided when you created the LDAP server. This is the directory service user you will be able to use with PCS.

### Set up PCS compute node group dependencies

Each compute node group needs a launch template that tells the EC2 instances how to configure themselves to connect to the directory server. This includes installing relevant software, creating a configuration file, and starting up some system services. The launch template we are using relies on being able to access AWS Secrets Manager to fetch the LDAP bind password. It also needs to be able to retrieve the SSD configuration file template from S3. Thus, we have to create an instance profile for the node group with the relevant AWS permissions. This recipe includes a CloudFormation stack that creates both assets together. In addition to the LDAP configuration bits, it configures key node group traits like SSH key, IMDS version, and SSM access. 

To create your node group dependencies:

1. Launch this [quick-create link](MEEP) in the region where you are configuring PCS.
2. Under **Compute node group options**
    * Select an SSH keypair for use by the default user (e.g. `ec2-user`)
    * Select security groups for the node group instances. Usually, the VPC `default` group will suffice.
3. Under **LDAP Configuration** provide values from the outputs of the LDAP server stack you deployed earlier
    * For `DomainName` fill in `Outputs.DomainName`
    * For `LdapUri` fill in `Outputs.LdapUri`
    * For `LdapSearchBase` fill in `Outputs.DomainComponents`
    * For `DomainServiceAccount` fill in `Outputs.DomainServiceAccount`
    * For `PasswordSecretArn` fill in `Outputs.PasswordSecretArn`
    * For `SssdConfigTemplateS3Path` select either the template starting with `ad.*` or `openldap.*`, depending on which LDAP server type you are connecting to.
4. Launch the stack and wait for it to reach `CREATE_COMPLETE`
5. Navigate to its outputs and take note of them. You will need them to configure a PCS compute node group.

### Create a PCS compute node group

* Open the AWS PCS console at https://console.aws.amazon.com/pcs/home#/clusters
* Select the cluster where you wish to create a compute node group. Navigate to Compute node groups and choose Create.
* In the Compute node group setup section, provide the following:
    * Compute node group name - A name for your node group.
* Under Computing configuration, enter these values:
    * EC2 launch template - Select the launch template that was created above.
    * EC2 launch template version - Choose `$Latest`
    * IAM instance profile - Select the instance profile that was created above. 
    * Subnets - Choose a subnet.
    * Instances - Choose instance types. Smaller, cheaper instances are good for prototyping. 
    * Scaling configuration - Use a static configuration to demonstrate multi-user configuration. Set the minimum and maximum instance count to 1. 
* Under Additional settings, specify the following:
    * AMI ID - Choose an AMI based on Amazon Linux 2, such as the PCS sample AMI. 

### Connect to a node in the PCS compute node group

Use EC2 tags to find instances in a compute node group using the AWS Management Console. 

To find your node group instances:

* Open the AWS PCS console at https://console.aws.amazon.com/pcs/home#/clusters
* Select the cluster where you wish to log in.
* Choose **Compute node groups**.
* Find the ID for a static compute node group you have created.
* Navigate to the [EC2 console](https://console.aws.amazon.com/ec2/) and choose **Instances**.
* Search for instances tagged with `aws-pcs:compute-node-group-id=NodeGroupID1` where `NodeGroupID1` is replaced with your own node group ID. 
* Select an instance
* Choose **Connect**

This will give you instructions on how to connect to the instance using the default user (usually `ec2-user` for SSH and `ssm-user` for Amazon SSM session manager). 

For now, connect using **Session Manager**. This will take you to a shell running in your browser, connected to the instance managed by PCS. 

### Demonstrate that directory service support is working

Your web shell prompt will look something like this `ssm-user@ip-10-3-129-5 bin]$` or `[ec2-user@ip-10-3-129-5 ~]$`. These are "local" users that exist on the instance, even if the instance isn't connected to a directory server. 

However, if LDAP server support is configured properly, you will be able to "switch users" to a directory user. It's time to put everything together - remember the sample username and password from when you created your directory server? Try switching to that user now.

For example, if your sample user was named `sampleuser`, enter this command: `su - sampleuser`. You will be prompted for a password. Enter the sample user password. 

You should be able to log into this directory service user - the system will show you a banner as it creates a home directory for the user. The screen should look something like this:

```shell
   ,     #_
   ~\_  ####_        Amazon Linux 2
  ~~  \_#####\
  ~~     \###|       AL2 End of Life is 2025-06-30.
  ~~       \#/ ___
   ~~       V~' '->
    ~~~         /    A newer version of Amazon Linux is available!
      ~~._.   _/
         _/ _/       Amazon Linux 2023, GA and supported until 2028-03-15.
       _/m/'           https://aws.amazon.com/linux/amazon-linux-2023/

[sampleuser@p-10-3-129-5]$
```

If your instance allows inbound SSH, you should be able to connect to it directly by SSH using the sample username and password: `ssh sampleuser@192.0.2.1`

### Next steps

*TBD*
