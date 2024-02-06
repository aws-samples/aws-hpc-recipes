# demo_managed_ad

## Info

This recipe sets up an AWS Managed Microsoft AD deployment that can support demonstrations of multi-user AWS ParallelCluster, Research and Engineering Studio, or other products. 

**Note** This template uses self-signed certificates to enable encrypted LDAP. Consult the documentation to learn [how to secure an AWS Managed Microsoft AD](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_security.html).

## Usage

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=managed-ad&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/main.yaml)
2. Follow the instructions in the AWS CloudFormation console.
    * Choose the VPC and subnets where your AD will be deployed. If you are launching the management host in a public subnet and wish to restrict the IPs allowed to connect to it via SSH, you can either provide a value for **AllowedIps** that maps to your own local IP address or network, or you can provide a AWS VPC Prefix List. Either will restrict inbound access to port 22 to the range(s) of IP addresses you have specified.
    * There are three settings to help control costs in this template. 1) You can choose the "Standard" edition of Microsoft Active Directory. 2) You can opt to shut the management instance off after it completes initializing your AD with **StopAdAdminInstance**. 3) You can change the EC2 instance type for the Linux management host using **AdDomainAdminNodeInstancetype**.
    * You can create a single AD user directly from the CloudFormation template by setting the **UserName** and **UserPassword** parameters. You may also bootstrap the directory using an LDIF file (see below for details).
3. Monitor the status of the stack. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. You will find several values you can use to connect a ParallelCluster instance or other product.

### User and Group Management via Linux Management Host

Once the stack has reached the `CREATE_COMPLETE` state, you can manage your groups and users via a Linux management host that is created automatically for you. 

#### Accessing the Linux host using SSM

To access the Linux host, go to the AWS CloudFormation stack in the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home). Next go to the **Resources** tab and select the **AdDomainAdminNode** and click **Physical ID** to open up the instance in the EC2 Console.

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/df21afe9-0cb6-46ed-a85c-58f9082dc204)

From the EC2 Console, select the instance and click **Connect**

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/f141a6a4-5edd-416d-981d-386fb5170c24)

Then select **Connect** to connect to the instance using AWS Session Manager which will bring up a web-based console on this instance.

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/5351d842-34c5-47a3-8fa0-7730acc8e903)

#### Accessing the Linux host using SSH

Follow the same instructions as for accessing the host by SSM, until you get to the **Connect** step. There, select **SSH Client** to get directions on how to connect with SSH. 

**Note** If you haven chosen **Yes** for the parameter **StopAdAdminInstance** whe  you launched the CloudFormation template, the Linux instance may be in a stopped state. Choose **Instance state::Start instance** to bring it back online before connecting to it. You can shut the instance down again when you are done working with it. 

#### Adding Users and Groups

This instance has the `adcli` and `ldapmodify`  CLI tools that allow you to update the ActiveDirectory to manage your groups and users.

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

You can search for the users that exist in your AD with the following command:

```
$ ldapsearch "(&(objectClass=user))" -x -h corp.pcluster.com -b "DC=corp,DC=pcluster,DC=com" -D "CN=Admin,OU=Users,OU=CORP,DC=corp,DC=pcluster,DC=com" -W
```

You can search for the groups that exist in your AD with the following command:

```
$ ldapsearch "(&(objectClass=group))" -x -h corp.pcluster.com -b "DC=corp,DC=pcluster,DC=com" -D "CN=Admin,OU=Users,OU=CORP,DC=corp,DC=pcluster,DC=com" -W
```

**Note** If you choose another domain name for your AD besides `corp.pcluster.com` you will need to change the `DC` values in the examples shown above. 

### User and Group Management via Windows Management Host

There is a [Windows Management Host](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=managed-adb&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/windows_management_host.yaml) stack that will launch a domain-joined Windows host. This template accepts a parameter (`PSS3Path`) for an S3 path (without the `s3://`) to a powershell script that will be run on the `DelegationUser` after the instance has joined the domain. This is useful for automating the setup of your domain using powershell commands. The host will have RDP open to the **ClientIpCidr** and/or the VPC Prefix List provided for **ClientPrefixList**. You can configure the host to reduce costs by shutting down after it launches using **StopAdminInstance**.

**Note**: It will take some time (~10m) after your Windows instance boots for it to join the domain. 

#### Accessing the Windows host

You may access this instance by going to the Outputs tab and copying the **ManagementHostId**. Next, navigate to the EC2 console and search for the instance ID. Copy its **Public IPv4 address** and use that with your RDP client to connect to the instance. The access credentials will be `Admin` and the value for **AdministratorPassword** you provided when you created the AD. 

**Note** If you haven chosen **Yes** for the parameter **StopAdminInstance** when you launched the CloudFormation template, the Windows instance may be in a stopped state. Choose **Instance state::Start instance** to bring it back online before connecting to it. You can shut the instance down again when you are done working with it. 

Once you connect to the instance, you may open the **Active Directory Users and Computers** interface by choosing to run that from the Windows Start menu:
![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/387f0abe-5db4-4d8d-aaff-9e42023f5dc9)

You can also use the PowerShell commands like [Get-ADUser](https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser?view=windowsserver2022-ps) to access the directory:

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/bf96cf6d-96ac-40c0-836a-e8c29405d1d2)

##### Troubleshooting

The EC2 launch agent’s error log is located at `C:\ProgramData\Amazon\EC2Launch\log\agent.log` and will specify where the bootstrap script is stored, as well as its error output. 

For example:

`cat C:\ProgramData\Amazon\EC2Launch\log\agent.log`

```
[...]
2023-10-07 22:39:05 Info: Script file is created at: C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch3800281881\UserScript.ps1
2023-10-07 22:39:05 Info: Error file is created at: C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch3800281881\err.tmp
2023-10-07 22:39:05 Info: Output file is created at: C:\Windows\system32\config\systemprofile\AppData\Local\Temp\EC2Launch3800281881\output.tmp
2023-10-07 22:40:27 Error: Error running task: failed to run task 'postReadyUserData-executeScript-0': failed to run script: Error occurred while executing script.
2023-10-07 22:40:27 Info: Stage: postReadyUserData completed.
2023-10-07 22:40:27 Info: Run StartSsm task.
2023-10-07 22:40:27 Info: AmazonSSMAgent service already running.
2023-10-07 22:40:27 Info: AmazonSSMAgent is running now.
2023-10-07 22:40:27 Info: Stage: postReady completed.
2023-10-07 22:40:27 Info: Run-once already exists: C:\ProgramData\Amazon\EC2Launch\state\.run-once
2023-10-07 22:40:27 Info: Replace C:\ProgramData\Amazon\EC2Launch\state\state.json with C:\ProgramData\Amazon\EC2Launch\state\previous-state.json
2023-10-07 22:40:27 Info: Success: C:\ProgramData\Amazon\EC2Launch\state\previous-state.json replaced C:\ProgramData\Amazon\EC2Launch\state\state.json
2023-10-07 22:40:27 Info: EC2Launch stopped
2023-10-07 22:42:26 Info: Configure wallpaper. Path: C:\ProgramData\Amazon\EC2Launch\wallpaper\Ec2Wallpaper.jpg; Attributes: hostName,instanceId,privateIpAddress,publicIpAddress,instanceSize,availabilityZone,architecture,memory,network; Instance Tags: Display none
2023-10-07 22:42:27 Info: Success: Completed wallpaper configuration.
```

##### Accessing the Windows management host as non-domain user

To access the instance as a non-domain host, open the [CloudFormation console](https://console.aws.amazon.com/cloudformation/home#/stacks), select your Windows Management Host stack and go to the **Resources** tab.

![image](https://github.com/charlesg3/aws-hpc-recipes/assets/6087509/db52f8b6-9c41-472d-b8b2-211815f99e9f)

Open the instance in the EC2 console by selecting it, then select it from the list and go to **Actions > Security > Get Windows password**, provide the PEM key for your keypair and select **Decrypt password**. This will open up a modal that has the administrator user and password. Copy these. Now open the host (using the DNS from the **Outputs** tab on the CloudFormation stack) to connect to the host directly.

### LDIF Support

The AD recipe provided here accept a parameter for an `LDIFS3Path`. This parameter is an S3 path (without the `s3://` prefix) to an LDIF file that will be imported on stack creation. This file must be accessible by the management host.

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
