
## Usage

This steps through the process of wiring up a Lambda function that updates a PCS cluster to use the latest Rocky Linux 8 AMI built by an Image Builder pipeline. 

### Create a source AMI

Follow the instructions in [build_amis](../build_amis/) to create a PCS-compatible Rocky Linux 8 AMI in a region where you will use PCS. Note the instance ID when complete.

### Create a PCS cluster that uses your custom Rocky 8 AMI for its compute node groups

Follow the instructions in [build_amis](../build_amis/). Note the `clusterIdentifier` for this cluster, since you will need it later. 

### Create an EC2 Image Builder pipeline (with an SNS topic)

Deploy an Image Builder pipeline using the [template in `assets`](assets/rocky8-pcs-imagebuilder-sns.yaml). 

1. Choose a descriptive name for the stack like `pipeline-1`.
2. Enter the ID of the Rocky 8 AMI you built for **ParentImageId**. 

### Create an execution role for the Lambda

First, create a Lambda execution role, then attach 3 inline policies. 

```shell
aws iam create-role \
  --role-name ClusterUpdaterLambdaRole \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": [
               "lambda.amazonaws.com"
          ]
        },
        "Action": "sts:AssumeRole"
      }
    ]
}'
```

### ClusterUpdaterCloudWatchLogs

This policy gives the Lambda permisison to write logs to CloudWatch.

Create and attach the policy, making the following substitutions: 

  * `REGION` - the region where your PCS cluster is deployed
  * `ACCOUNTID` - your AWS account ID

```shell
aws iam put-role-policy \
  --role-name ClusterUpdaterLambdaRole \
  --policy-name ClusterUpdaterCloudWatchLogs \
  --policy-document '{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Action": "logs:CreateLogGroup",
			"Resource": "arn:aws:logs:REGION:ACCOUNTID:*"
		},
		{
			"Effect": "Allow",
			"Action": [
				"logs:CreateLogStream",
				"logs:PutLogEvents"
			],
			"Resource": [
				"arn:aws:logs:REGION:ACCOUNTID:log-group:/aws/lambda/cluster-updater:*"
			]
		}
	]
}'
```

#### ClusterUpdaterPcsActions

This policy gives the Lambda permission to take some PCS mangaement actions. 

Create and attach the policy, making the following substitutions: 

  * `REGION` - the region where your PCS cluster is deployed
  * `ACCOUNTID` - your AWS account ID
  * `CLUSTERID` - the `clusterIdentifier` for your PCS cluster

```shell
aws iam put-role-policy \
  --role-name ClusterUpdaterLambdaRole \
  --policy-name ClusterUpdaterPcsActions \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "pcs:ListClusters",
                "pcs:GetCluster",
                "pcs:ListComputeNodeGroups",
                "pcs:GetComputeNodeGroup",
                "pcs:UpdateComputeNodeGroup"
            ],
            "Resource": "arn:aws:pcs:REGION:ACCOUNTID:cluster/CLUSTERID*",
            "Effect": "Allow"
        }
    ]
}'
```

#### ClusterUpdaterPcsServiceRoleEmulator 

While PCS is in beta, it is required to attach this policy to Lambda execution roles. When PCS reaches GA, it will be able to use a Service-linked role to take these actions on your behalf. 

```shell
aws iam put-role-policy \
  --role-name ClusterUpdaterLambdaRole \
  --policy-name ClusterUpdaterPcsServiceRoleEmulator \
  --policy-document '{
       "Statement": [
        {
         "Action": "ec2:CreateNetworkInterface",
         "Condition": {
          "Null": {
           "aws:RequestTag/AWSPCSManaged": "false"
          }
         },
         "Effect": "Allow",
         "Resource": "arn:aws:ec2:*:*:network-interface/*",
         "Sid": "PermissionsToCreatePCSNetworkInterfaces"
        },
        {
         "Action": "ec2:CreateNetworkInterface",
         "Effect": "Allow",
         "Resource": [
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:subnet/*"
         ],
         "Sid": "PermissionsToCreatePCSNetworkInterfacesInSubnet"
        },
        {
         "Action": [
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface"
         ],
         "Condition": {
          "Null": {
           "aws:ResourceTag/AWSPCSManaged": "false"
          }
         },
         "Effect": "Allow",
         "Resource": "arn:aws:ec2:*:*:network-interface/*",
         "Sid": "PermissionsToManagePCSNetworkInterfaces"
        },
        {
         "Action": [
          "ec2:DescribeImageAttribute",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceAttribute",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstances",
          "ec2:DescribeKeyPairs",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs"
         ],
         "Effect": "Allow",
         "Resource": "*",
         "Sid": "PermissionsToDescribePCSResources"
        },
        {
         "Action": "ec2:CreateLaunchTemplate",
         "Condition": {
          "Null": {
           "aws:RequestTag/AWSPCSManaged": "false"
          }
         },
         "Effect": "Allow",
         "Resource": "arn:aws:ec2:*:*:launch-template/*",
         "Sid": "PermissionsToCreatePCSLaunchTemplates"
        },
        {
         "Action": [
          "ec2:CreateLaunchTemplateVersion",
          "ec2:DeleteLaunchTemplate"
         ],
         "Condition": {
          "Null": {
           "aws:ResourceTag/AWSPCSManaged": "false"
          }
         },
         "Effect": "Allow",
         "Resource": "arn:aws:ec2:*:*:launch-template/*",
         "Sid": "PermissionsToManagePCSLaunchTemplates"
        },
        {
         "Action": "ec2:TerminateInstances",
         "Condition": {
          "Null": {
           "aws:ResourceTag/AWSPCSManaged": "false"
          }
         },
         "Effect": "Allow",
         "Resource": "arn:aws:ec2:*:*:instance/*",
         "Sid": "PermissionsToTerminatePCSManagedInstances"
        },
        {
         "Action": "iam:PassRole",
         "Condition": {
          "StringEquals": {
           "iam:PassedToService": [
            "ec2.amazonaws.com",
            "ec2.amazonaws.com.cn"
           ]
          }
         },
         "Effect": "Allow",
         "Resource": "arn:aws:iam::*:role/*",
         "Sid": "PermissionsToPassRoleToEC2"
        },
        {
         "Action": "iam:CreateServiceLinkedRole",
         "Condition": {
          "StringEquals": {
           "iam:AWSServiceName": [
            "spot.amazonaws.com",
            "spotfleet.amazonaws.com",
            "ec2fleet.amazonaws.com"
           ]
          }
         },
         "Effect": "Allow",
         "Resource": "*",
         "Sid": "PermissionsToCreateEC2SLR"
        },
        {
         "Action": [
          "ec2:CreateFleet",
          "ec2:RunInstances"
         ],
         "Effect": "Allow",
         "Resource": [
          "arn:aws:ec2:*:*:capacity-reservation/*",
          "arn:aws:ec2:*:*:fleet/*",
          "arn:aws:ec2:*:*:key-pair/*",
          "arn:aws:ec2:*:*:launch-template/*",
          "arn:aws:ec2:*:*:network-interface/*",
          "arn:aws:ec2:*:*:placement-group/*",
          "arn:aws:ec2:*:*:security-group/*",
          "arn:aws:ec2:*:*:subnet/*",
          "arn:aws:ec2:*:*:volume/*",
          "arn:aws:ec2:*::image/*",
          "arn:aws:ec2:*::snapshot/*",
          "arn:aws:resource-groups:*:*:group/*"
         ],
         "Sid": "PermissionsToControlClusterInstanceAttributes"
        },
        {
         "Action": [
          "ec2:CreateFleet",
          "ec2:RunInstances"
         ],
         "Condition": {
          "Null": {
           "aws:RequestTag/AWSPCSManaged": "false"
          }
         },
         "Effect": "Allow",
         "Resource": "arn:aws:ec2:*:*:instance/*",
         "Sid": "PermissionsToProvisionClusterInstances"
        },
        {
         "Action": "ec2:CreateTags",
         "Condition": {
          "StringEquals": {
           "ec2:CreateAction": [
            "RunInstances",
            "CreateLaunchTemplate",
            "CreateFleet",
            "CreateNetworkInterface"
           ]
          }
         },
         "Effect": "Allow",
         "Resource": "*",
         "Sid": "PermissionsToTagPCSResources"
        },
        {
         "Action": "cloudwatch:PutMetricData",
         "Condition": {
          "StringEquals": {
           "cloudwatch:namespace": "AWS/PCS"
          }
         },
         "Effect": "Allow",
         "Resource": "*",
         "Sid": "PermissionsToPublishMetrics"
        }
       ],
       "Version": "2012-10-17"
      }'
```

### Package the Lambda function for deployment

Change into the `lambda_function` directory. Then, zip the Python file and AWS PCS model file into a package.

```
zip -r ../lambda_function.zip .
```

Change back to the main source directory to deploy the zipfile to AWS.

**Note** The models folder contains the latest build of the PCS service model. It must be included at the top level of the Lambda zipfile. 

### Deploy the Lambda function using the zip file

Run the command that follows, making these substitutions: 

  * `REGION` - the region where your PCS cluster is deployed
  * `ACCOUNTID` - your AWS account ID
  * `CLUSTERID` - the `clusterIdentifier` for your PCS cluster

```shell
aws lambda create-function \
    --function-name cluster-updater \
    --runtime python3.12 --handler lambda_function.lambda_handler \
    --role arn:aws:iam::ACCOUNTID:role/ClusterUpdaterLambdaRole \
    --zip-file fileb://lambda_function.zip \
    --timeout 30 \
    --environment "Variables={AWS_DATA_PATH=/var/task/models,PCS_CLUSTER_IDENTIFIER=CLUSTERID,PCS_CLUSTER_REGION=REGION}" \
    --logging-config "LogFormat=Text,LogGroup=/aws/lambda/cluster-updater"
```

**Note** Recall we package a `models` directory with the Lambda. Setting `AWS_DATA_PATH` to `/var/task/models` informs botocore to [look for additional models at this location](https://botocore.amazonaws.com/v1/documentation/api/latest/reference/loaders.html).

If you need to update your cluster source code (or the service model), repackage it as a zip file, then run the following command:

```shell
aws lambda update-function-code \
    --function-name cluster-updater \
    --zip-file fileb://lambda_function.zip
```

### Subscribe the Lambda to your Image Builder SNS topic

Find the ARN for your ImageBuilder pipeline SNS topic.

1. Go to the CloudWatch console. 
2. Navigate to the stack you deployed to create an ImageBuilder pipeline
3. Under **Outputs**, find **PipelineSnsTopic**

Run the command that follows, making these substitutions: 

  * `TOPICARN` - the value for **PipelineSnsTopic**

```shell
aws lambda add-permission --function-name cluster-updater \
    --source-arn TOPICARN \
    --statement-id sns-same-account --action "lambda:InvokeFunction" \
    --principal sns.amazonaws.com
```

Run the command that follows, making these substitutions: 

  * `REGION` - the region where your PCS cluster is deployed
  * `ACCOUNTID` - your AWS account ID
  * `TOPICARN` - the value for **PipelineSnsTopic**

```shell
aws sns subscribe --protocol lambda \
    --topic-arn TOPICARN \
    --notification-endpoint arn:aws:lambda:REGION:ACCOUNTID:function:cluster-updater
```

### Test the integration

Go to your ImageBuilder pipeline. Trigger it. When the new image has built, watch the CloudWatch logs for your Lambda. A successful run will look something like this

```
INIT_START Runtime Version: python:3.12.v25	Runtime Version ARN: arn:aws:lambda:us-east-1::runtime:eb23ce52a7ad2bcf849de9f8cb1e3bae200e62ddb9e03883cc29d7c7a5eade03
START RequestId: 0e0a86e7-945e-4dd8-a14a-924e6a385f45 Version: $LATEST
[INFO]	2024-05-13T17:38:48.299Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	TopicArn: arn:aws:sns:us-east-1:609783872011:image-builder-topic
[INFO]	2024-05-13T17:38:48.299Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	MessageId: 548e2b98-89b2-5fa6-97ad-7524dbd59fec
[INFO]	2024-05-13T17:38:48.299Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	Subject: None
[INFO]	2024-05-13T17:38:48.299Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	Region: us-east-1
[INFO]	2024-05-13T17:38:48.299Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	ClusterId: pieixxx15i
[INFO]	2024-05-13T17:38:48.427Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	Initializing PCS client
[INFO]	2024-05-13T17:38:48.507Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	Found credentials in environment variables.
[INFO]	2024-05-13T17:38:49.546Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	No endpoints ruleset found for service pcs, falling back to legacy endpoint routing.
[INFO]	2024-05-13T17:38:49.625Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	amiId: ami-0c45cdf8be884ff5e
[INFO]	2024-05-13T17:38:49.625Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	Listing compute node groups for pieixxx15i
[INFO]	2024-05-13T17:38:50.478Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	Updating compute node groups
[INFO]	2024-05-13T17:38:50.478Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	ComputeNodeGroupId: 3t9fl7ui6s
[INFO]	2024-05-13T17:38:51.005Z	0e0a86e7-945e-4dd8-a14a-924e6a385f45	ComputeNodeGroupId: i7jevxks2k
END RequestId: 0e0a86e7-945e-4dd8-a14a-924e6a385f45
REPORT RequestId: 0e0a86e7-945e-4dd8-a14a-924e6a385f45	Duration: 3066.60 ms	Billed Duration: 3067 ms	Memory Size: 128 MB	Max Memory Used: 76 MB	Init Duration: 289.19 ms
```

Go to the PCS console and navigate to the cluster you are attempting to update. Go to its compute node groups. Each node group should be updated at or a little after the timestamp in the CloudWatch Logs above. The AMI ID for each node group should be the value output in the logs above for `amiId` (in this case, `ami-0c45cdf8be884ff5e`). 

