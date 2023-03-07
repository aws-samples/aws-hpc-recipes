# HPC Development Kit (HPCDK)

This is a prototype library of interoperable blueprints for HPC infrastructure. More will be written in the future, but for now here's the gist:

We can launch a ParallelCluster system as custom resource with CloudFormation that looks something like this:

```yaml
Resources:

PclusterCluster:
    Type: Custom::PclusterCluster
    Properties:
      ServiceToken: !GetAtt [ PclusterCfn , Outputs.Function ]
      ClusterName: !Ref ClusterName
      ClusterConfiguration:
        Image:
          Os: !Ref OS
        HeadNode:
          InstanceType: t2.large
          Networking:
            SubnetId: !GetAtt [ PclusterVpc , Outputs.PublicSubnetA ]
            AdditionalSecurityGroups:
              - !GetAtt [ PclusterAcctDatabase , Outputs.DatabaseClientSecurityGroup ]
          Ssh:
            KeyName: !Ref KeyName
          Iam:
            AdditionalIamPolicies:
            - Policy: arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
        Scheduling:
          Scheduler: slurm
          SlurmSettings:
            Database:
              Uri: !GetAtt [ PclusterAcctDatabase , Outputs.DatabaseHost ]
              UserName: !GetAtt [ PclusterAcctDatabase , Outputs.DatabaseAdminUser ]
              PasswordSecretArn: !GetAtt [ PclusterAcctDatabase , Outputs.DatabaseSecretArn ]
          SlurmQueues:
          - Name: queue0
            ComputeResources:
            - Name: queue0-i0
              Instances:
              - InstanceType: t2.medium
              - InstanceType: t3.small
              MinCount: 0
              MaxCount: !Ref ComputeInstanceMax
            Networking:
              SubnetIds:
              - !GetAtt [ PclusterVpc , Outputs.PublicSubnetA ]
              - !GetAtt [ PclusterVpc , Outputs.PublicSubnetB ]
```

Obviously, I'm leaving a lot out. Where is `PclusterVpc` defined? Or `PclusterAcctDatabase`?. That's the point. They're coming from resources defined by other CloudFormation stacks. 

This repository will demonstrate one-shot creation of complex HPC architectures that currently rely on hand-integration of multiple independent AWS resources. Examples include:
* ParallelCluster with Slurm accounting
* ParallelCluster along with ParallelCluster UI
* ParallelCluster with non-managed FSx and EFS storage
* ParallelCluster with Budgets + Billing Alerts

## Using

Deploy resources in the `resources/` directory using CloudFormation. 

## Developing

1. Install and configure the AWS CLI
2. Install [cfn-lint](https://github.com/aws-cloudformation/cfn-lint)
3. Create an S3 bucket `S3_BUCKET_NAME` to hold Cloudformation assets
4. (Optional) Lint any new or updated CloudFormation templates with cfn-lint
5. Deploy to the bucket with `aws s3 sync --acl public-read resources s3://S3_BUCKET_NAME/resources/`
