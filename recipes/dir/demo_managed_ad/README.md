# demo_managed_ad

## Info

This recipes sets up a basic AWS Managed Microsoft AD deployment that can support a demonstration multi-user environment in AWS ParallelCluster or other products. 

**Note** This template uses self-signed certificates to enable encrypted LDAP. Consult the documentation to learn [how to secure an AWS Managed Microsoft AD](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_security.html).

## Usage

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=managed-adb&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/main.yaml)
2. Follow the instructions in the AWS CloudFormation console. Choose the VPC and subnets where your AWS ParallelCluster deployment will be created. 
3. Monitor the status of the stack. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. You will find several values you can use to create a ParallelCluster instance or other product.

You can include the Output values directly in a cluster configuration, as per the [ParallelCluster documentation](https://docs.aws.amazon.com/parallelcluster/latest/ug/multi-user-v3.html). Alternatively, if you are deploying a cluster with AWS CloudFormation, these values have been exported so you may import them into your template using the `[Fn::Import](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference-importvalue.html)` intrinsic function. 

**Note** If you wish to import networking configuration directly from an existing CloudFormation stack, you can use the alternative [import template](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=managed-adb&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/main-import.yaml), providing the name of an active HPC Recipes for AWS networking stack.

### User and Group Management via Management Host

Once the stack has reached the `CREATE_COMPLETE` state, you can manage your groups and users via the Linux management host. 

#### Accessing the management host

To access the management host, go to the AWS CloudFormation stack in the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home).

Next go to the **Resources** tab and select the **AdDomainAdminNode** and click the **Physical ID** to open up the instance in the EC2 Console.

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/df21afe9-0cb6-46ed-a85c-58f9082dc204)

From the EC2 Console, select the instance an click **Connect**

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/f141a6a4-5edd-416d-981d-386fb5170c24)

Then select **Connect** to connect to the instance using AWS Session Manager which will bring up a console to this instance.

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/5351d842-34c5-47a3-8fa0-7730acc8e903)

This instance has the `adcli` and `ldapmodify`  CLI tools that allow you to update the ActiveDirectory to manage your groups and users.

#### Adding Users and Groups

In the following example we use the `adcli` commands in the management host described above to add a new group `mygroup` a new user `myuser` and add the user to the group. Additionally we use the `ldapmodify` command which accepts LDIF format to add the `gidNumber` property to the group.

```.sh
ssm-user@ip-10-3-140-155 bin]$ export ADMIN_PASSWORD=[YOURPASSWORD] # replace or provide in the ldapmodify command below
ssm-user@ip-10-3-140-155 bin]$ export DOMAIN=corp.pcluster.com # replace with your domain
[ssm-user@ip-10-3-140-155 bin]$ adcli create-group "mygroup" --domain ${DOMAIN} -U "Admin"
Password for Admin@CORP.PCLUSTER.COM:
[ssm-user@ip-10-3-140-155 bin]$ adcli create-user myuser --display-name "New User" --mail="myuser@${DOMAIN}" --unix-home=/home/myuser --unix-gid=1001 --unix-shell=/bin/bash --unix-uid=1001 --domain ${DOMAIN} -U "Admin"
Password for Admin@CORP.PCLUSTER.COM:
[ssm-user@ip-10-3-140-155 bin]$ adcli add-member mygroup myuser --domain ${DOMAIN} -U Admin
Password for Admin@CORP.PCLUSTER.COM:
[ssm-user@ip-10-3-140-155 bin]$  ldapmodify -x -h ${DOMAIN} -D "CN=Admin,OU=Users,OU=CORP,DC=corp,DC=pcluster,DC=com" -w ${ADMIN_PASSWORD} << EOF
dn: CN=mygroup,OU=Users,OU=corp,DC=corp,DC=pcluster,DC=com
> changetype: modify
> add: gidNumber
> gidNumber: 1001
> EOF
modifying entry "CN=mygroup,OU=Users,OU=corp,DC=corp,DC=res,DC=com"
```

### LDIF Support

Both of the recipes provided here accept a parameter for an `LDIFS3Path`. This parameter is an S3 path (without the `s3://` prefix) to an LDIF file that will be imported on stack creation. This file must be accessible by the management host.

LDIF (LDAP data interchange format) is a standard text-based format used to represent LDAP objects and updates. Providing this file can bootstrap the users and groups in your environment in an automated way.

An example file to start form is provided in the `assets` and looks like the following:

```.ldif
# Add a user
dn: CN=myuser,OU=Users,OU=corp,DC=corp,DC=pcluster,DC=com
changetype: add
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: user
cn: myuser
name: myuser
userPrincipalName: myuser@corp.pcluster.com
mail: myuser@corp.pcluster.com
uidNumber: 1001
gidNumber: 1001
unixHomeDirectory: /home/myuser
loginShell: /bin/bash

# Add a group and add above user to that group
dn: CN=mygroup,OU=Users,OU=corp,DC=corp,DC=pcluster,DC=com
changetype: add
objectClass: top
objectClass: group
cn: mygroup
description: mygroup
distinguishedName: CN=mygroup,OU=Users,OU=corp,DC=corp,DC=pcluster,DC=com
name: mygroup
sAMAccountName: mygroup
objectCategory: CN=Group,CN=Schema,CN=Configuration,DC=corp,DC=pcluster,DC=com
gidNumber: 1002
member: CN=myuser,OU=Users,OU=corp,DC=corp,DC=pcluster,DC=com
```
You can start with this file, upload it to an S3 bucket and provide the path to one of the templates to have the LDAP objects created when the stack starts.

## Cost Estimate

It will cost approximately $72.00 to run this directory service for a week. 

## Cleaning Up

When you are done using this resource, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
