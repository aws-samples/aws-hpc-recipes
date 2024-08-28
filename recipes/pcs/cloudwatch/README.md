# Enable CloudWatch Logs on PCS instances

## Info

This recipe contains assets to help you implement the recommendations in [_Monitoring AWS PCS instances using Amazon CloudWatch_](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring-cloudwatch_instances.html) in the AWS PCS user guide.

## Usage

Several files in the [`assets`](assets/) directory will be of use.

* `config.json` - This is an example CloudWatch agent file you can use to configure logging and persistent instance metrics on Amazon Linux 2. If your instances will use a different operating system, change the paths as appropriate.
