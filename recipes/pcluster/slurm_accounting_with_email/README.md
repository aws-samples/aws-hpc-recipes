# ParallelCluster with Slurm Accounting Enabled and E-mail Notifications

**Note:** This recipe is based upon [ParallelCluster with Slurm Accounting Enabled](../slurm_accounting/README.md)

## Info

Creates an instance of AWS ParallelCluster with Slurm accounting enabled, using Amazon RDS as the database management server and [Slurm-Mail](https://github.com/neilmunday/slurm-mail) configured for e-mail notifications for job events.

An alternative Cloudformation template is also provided to enable SMS notifications via SMS for job events.

## Requirements

Before attempting to make use of the templates provided by this recipe please make sure you have completed the following requirements:

* Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
* Create a HPC networking stack using the **HPC Recipes for AWS** collection and take note of its name.
* Ensure you have a [SES e-mail identity created and verified](https://docs.aws.amazon.com/ses/latest/dg/creating-identities.html#verify-email-addresses-procedure). As long as you have verified your e-mail address you do not need to leave the SES sandbox.
* Ensure you have created a [SMTP user](https://docs.aws.amazon.com/ses/latest/dg/smtp-credentials.html) and taken note of the SMTP user name, password and server name.

If you also plan to use the SMS notification template also make sure you have added a [SMS number and have verified it](https://docs.aws.amazon.com/sns/latest/dg/sns-sms-sandbox-verifying-phone-numbers.html), otherwise you can skip this requirement.

## Launch the Cluster, Database and Slurm-Mail

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=sacct-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/slurm_accounting_with_email/assets/launch.yaml)
2. Follow the instructions in the AWS CloudFormation console. As you work through the template, mind these points:
  * The value you enter for **NetworkStackNameParameter** must be the name of your HPC networking stack
  * Don't set a value for **AdminPasswordSecretString** that is used anywhere else
  * Make sure you use a verified SES identity (e-mail address)
  * Make sure you use the correct SMTP credentials
3. Monitor the status of the stack. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. Find the output named **HeadNodeIp** - this is the public IP address for your cluster login node.

## Launch the Cluster, Database and Slurm-Mail with SMS Nofitications

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=sacct-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/slurm_accounting_with_email/assets/launch-sms.yaml)
2. Follow the instructions in the AWS CloudFormation console. As you work through the template, mind these points:
  * The value you enter for **NetworkStackNameParameter** must be the name of your HPC networking stack
  * Don't set a value for **AdminPasswordSecretString** that is used anywhere else
  * Make sure you use a verified SES identity (e-mail address)
  * Make sure you use the correct SMTP credentials
  * Make sure you use a mobile number which has been verified by SNS
3. Monitor the status of the stack. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. Find the output named **HeadNodeIp** - this is the public IP address for your cluster login node.

## Access the Cluster and Try Slurm Accounting with E-mail Notifications

You can either log in via SSH to the **HeadNodeIp** using the keypair you specified, or you can use Amazon Systems Manager to log from the AWS EC2 Console. Once you are logged into the system, you can test out a couple of commands that confirm Slurm accounting is active. 
1. Try using the [sacct](https://slurm.schedmd.com/sacct.html) command to display accounting data for all jobs and job steps in the Slurm database. 
2. Try out the [sacctmgr](https://slurm.schedmd.com/sacctmgr.html) command. It is used to configure accounting in detail. 
3. Submit a job and check your inbox for job notification e-mails. Remember to use the `--mail-type` and `--mail-user` options for `sbatch`, e.g.

```
#!/usr/bin/bash

#SBATCH -J my_job
#SBATCH -n 1
#SBATCH --mail-user=me@example.com
#SBATCH --mail-type=ALL
echo "hello world
sleep 60
```

## Troubleshooting

1. Check the contents `/var/log/slurm-mail/slurm-send-mail.log` for any errors.
2. Check that your e-mail identity has been verified for the region where you have deployed the stack.
3. Perform the steps at [send-email-smtp-client-command-line.html](https://docs.aws.amazon.com/ses/latest/dg/send-email-smtp-client-command-line.html) to check your SMTP connection.
4. If you are using the SMS template, check the CloudWatch logs for the `PclusterSMSLambdaFunction` and check your SMS spending limit - you may need to request an increase

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. There will also be a charge for the Amazon RDS cluster and for each e-mail sent ($0.10/1000 emails). Based on on-demand pricing for the relevant instances, it should cost between $30 to $50.00 to run the cluster for a week, submitting a handful of jobs. 

If you are using the SMS template the cost of sending SMS notifications varies by region. See [sms-pricing](https://aws.amazon.com/sns/sms-pricing/) for details.

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the relevant stack.  
