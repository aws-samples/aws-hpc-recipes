# ParallelCluster with Multi-User Access Enabled

## Info

Creates a multi-user instance of AWS ParallelCluster using AWS Managed AD as the directory service. This recipe supplements the AWS ParallelCluster [documentation](https://docs.aws.amazon.com/parallelcluster/latest/ug/multi-user-v3.html) and [tutorial](https://docs.aws.amazon.com/parallelcluster/latest/ug/tutorials_05_multi-user-ad.html). Please be advised that this stack should never be used outside training or educational demonstrations, as it configures the cluster without TLS encryption.

## Usage

### Configure a multi-AZ networking stack

1. Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters in. If you named the networking stack something besides **hpc-networking**, make a note of that as you will need it to set up your cluster. 

### Launch the Cluster and AD Server

1. Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster and AD management instance.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=multiuser-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/multi_user/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. As you work through the template, mind these points:
  * The value you enter for **NetworkStackNameParameter** must be the name of your HPC networking stack
  * The template requires you to provide a valid CIDR notation (X.X.X.X/X) to secure access to the login node. This is because you are enabling password authentication on an SSH connection. It is disabled by default for security purposes.
  * The values you provide for `UserName` and `UserPassword` are the credentials you will use to log into the cluster. Choose an appropriately strong password!

### Access the Cluster

You can always use the administrator SSH keypair or Amazon Systems Manager to log into cluster. However, the point of this exercise is to demonstrate access using a username and password managed by a directory service. 

Try it out with `ssh UserName@HeadNodeIp`. You will be prompted for a password - type in the value you provided for `UserPassword`. You should see something similar to the text below.

```shell
$ ssh user000@1.2.3.4
user000@3.145.108.47's password: *****

Creating directory '/home/user000'.

       __|  __|_  )
       _|  (     /   Amazon Linux 2 AMI
      ___|\___|___|

https://aws.amazon.com/amazon-linux-2/
[user000@ip-10-0-0-32 ~]
```

### Managing AD

To add or manage users in the directory service, you will need to log into the AD management instance created by the ManagedAD nested stack. There is a detailed write-up of how to do this in the [AWS ParallelCluster documentation](https://docs.aws.amazon.com/parallelcluster/latest/ug/tutorials_05_multi-user-ad.html). But, you will retrieve four key values from your stack outputs to accomplish the various tasks:

1. The ID of the Managed AD: `Outputs.AdDirectoryId`
2. The relevant AD domain: `Outputs.AdDomainName`
3. The address of the AD LDAP server: `Outputs.AdLDAPAddress`
4. The AD administrator password `Outputs.AdAdminPasswordSecretArn`

In the tutorial documents, when you run `ldapsearch` commands, you need to provide a host. It is the IP address from `Outputs.AdLDAPAddress`. 

You will also be prompted sometimes to provide the AD admin password. You can retrieve it using the AWS CLI. Assuming the value for Outputs.AdAdminPasswordSecretArn is `arn:aws:secretsmanager:us-east-2:111111111111:secret:Pcluster-AD-Admin-Password-qABCDEF`, you can retrieve the password like this:

```shell
aws secretsmanager get-secret-value --secret-id arn:aws:secretsmanager:us-east-2:111111111111:secret:Pcluster-AD-Admin-Password-qABCDEF

{
    "ARN": "arn:aws:secretsmanager:us-east-2:111111111111:secret:Pcluster-AD-Admin-Password-qABCDEF",
    "Name": "Pcluster-AD-Admin-Password",
    "VersionId": "19173fd1-c4f0-fb9c-189f-db578159cdf6",
    "SecretString": "arM0upUCVeeydk21KKQ5BzK3jKbir2zG",
    "VersionStages": [
        "AWSCURRENT"
    ],
    "CreatedDate": "2023-08-29T07:06:00.496000-04:00"
}
```

The secret's decrypted value is revealed in `SecretString`.

## Key Details

In the ParallelCluster documentation for integrating with AWS Managed Microsoft AD, the quick-launch template requires you to provide an administrator and read-only user password. In this example template, those are generated for you via the `AdminPasswordSecret` and `ReadonlyPasswordSecret` resources. Their values are then passed to the nested stack that creates the AD using a dynamic reference. Using this approach, you can generate and store a secret without ever having to write it down somewhere insecure, like a sticky note next to your workstation. 

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. Based on on-demand pricing for the relevant EC2 instances and the cost of the directory service, it should cost between $30 to $50.00 to run this cluster for a week, submitting a handful of jobs each day. 

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the **multiuser-cluster** stack. 
