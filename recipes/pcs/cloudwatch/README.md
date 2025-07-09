# Enable CloudWatch Logs on PCS

## Info

This recipe contains assets to help you implement the recommendations in [_Monitoring AWS PCS instances using Amazon CloudWatch_](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring-cloudwatch_instances.html) in the AWS PCS user guide. It also has assets to help you configure a PCS cluster to send [scheduler](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring_scheduler-logs.html) and [job completion](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring_job-completion-logs.html) logs to CloudWatch. 

## Usage

Several files in the [`assets`](assets/) directory will be of use.

* `config.json` - This is an example CloudWatch agent file you can use to configure logging and persistent instance metrics on Amazon Linux 2. If your instances will use a different operating system, change the paths as appropriate.
* `cloudwatch_log_delivery.cfn.yaml` - This is an example of how to enable Cloudwatch Log delivery on a PCS Cluster. Check out the HPC recipes repo or download the [CloudFormation template](assets/cloudwatch_log_delivery.cfn.yaml), then run a command resembling this one:
```shell
stack_id=$(aws cloudformation create-stack \
               --region us-east-2 \
               --capabilities "CAPABILITY_NAMED_IAM" "CAPABILITY_AUTO_EXPAND" \
               --parameters \
               ParameterKey=PCSClusterId,ParameterValue=pcs_XXXXXXXXXX \
               --output text \
               --query "StackId" \
               --stack-name "pcsLogDelivery" \
               --template-body file://$PWD/cloudwatch_log_delivery.cfn.yaml)
```
