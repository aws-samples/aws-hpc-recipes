# Login Node AMI for Research and Engineering Studio (RES)

## Info

This recipe allows enables the creation an of a [ParallelCluster Login node](https://docs.aws.amazon.com/parallelcluster/latest/ug/login-nodes-v3.html) AMI compatible with [Research and Engineering Studio (RES)](https://github.com/aws/res). This allows for a software stack to be created within RES that can integrate with ParallelCluster.

## Usage

### 1. Deploy Login Node AMI automation

You can launch this template by following this quick-create link:

- Create [Login Node AMI for RES](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=loginnode-for-res&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/login_node_for_res/assets/main.yaml)

If you don't wish to use the quick-create link, you can also download the [assets/main.yaml](assets/main.yaml) file and uploading it to [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation).

### 2. Trigger automation

1. Download [1-create-ami.sh](recipes/pcluster/login_node_for_res/assets/1-create-ami.sh).
2. Run `1-create-ami.sh` once your Login Node is ready for snapshot. Update the following parameters accordingly.
   1. `PC_CLUSTER_NAME` = ParallelCluster cluster name
   2. `RES_STACK_NAME` = RES Stack name

```bash
Usage: ./1-create-ami.sh <PC_CLUSTER_NAME> <RES_STACK_NAME>
```

**Note:** If execution times out, check Systems Manager for the Automation execution.  
_Systems Manager -> Automation -> {{execution id from command output}}_
e.g. `cd95c7b6-9999-aaaa-9beb-7c4bdbd57900`

_sample output_

```
[-] Automation execution started with ID: cd95c7b6-9999-aaaa-9beb-7c4bdbd57900
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Waiting for automation execution to complete... Retrying in 20s
[-] Automation execution completed successfully.
[-] Outputs: ami-xxxxxxxxxxxx
Done!
```

### 3. Create Software stack in Research and Engineering Studio (RES) for Login Node

Use the following steps to create a ParallelCluster LoginNode Software Stack in RES.

1.  Login to RES as an Administrator
2.  Select **Software Stacks**
3.  Select **Register Software Stack**
    1.  **Name**: LoginNode-<cluster-name>
    2.  **Description**: LoginNode for cluster <cluster-name>
    3.  **AMI ID**: <Output from `1-create-ami.sh`>
    4.  **Operating System**: <Select the OS used for the ParallelCluster - e.g. alinux2>
    5.  **Min Storage Size**: 40GB
    6.  **Min Ram**: 10GB
    7.  Select Project(s) to associate the stack
    8.  Select **Submit**

Deploy a new Desktop for the ParallelCluster LoginNode

### 4. Post-Deployment steps

Once the LoginNode Desktop has been provisioned run the following command to allow the desktop to bootstrap properly.

**Note:** `INSTANCE_ID` can be found under _Actions -> Show Info_ for the

```bash
aws ssm send-command \
  --instance-ids "<INSTANCE_ID>" \
  --document-name "ConfigureDcvHostLoginNode"
```

## Cost Estimate

Costs for this solution is less than $1.00/month.
