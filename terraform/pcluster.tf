
provider "aws" {
    alias = "region"
}

data "aws_region" "current" {
    provider = "aws.region"
}

resource "aws_cloudformation_stack" "pcluster" {
  name = "pcluster-stack"

  parameters = {
    ClusterName = "myclustertf"
  }

  capabilities = ["CAPABILITY_IAM"]

  template_body = <<STACK
{
  "Parameters": {
    "ClusterName": {
      "Type": "String",
      "Default": "mycluster",
      "Description": "Name of the cluster to be creatd."
    }
  },
  "Resources": {
    "PclusterCfn": {
      "Type": "AWS::CloudFormation::Stack",
      "Properties": {
        "Parameters": {
          "ParallelClusterVersion": "3.1.4"
        },
        "TemplateURL": "https://aws-parallelcluster-dev-cgruenwa.s3.us-east-2.amazonaws.com/pcluster-cfn.yaml",
        "TimeoutInMinutes": 10
      }
    },
    "PclusterCluster": {
      "Type": "Custom::PclusterCluster",
      "Properties": {
        "ServiceToken": {"Fn::GetAtt": ["PclusterCfn","Outputs.Function"]},
        "Region": "${data.aws_region.current.name}",
        "ClusterName": {"Ref": "ClusterName"},
        "ClusterConfiguration": {
          "Image": {"Os": "alinux2"},
          "HeadNode": {
            "InstanceType": "t2.large",
            "Networking": {
              "SubnetId": "subnet-01ff8b514162d9a92"
            },
            "Ssh": {"KeyName": "enguard"}
          },
          "Scheduling": {
            "Scheduler": "slurm",
            "SlurmQueues": [
              {
                "Name": "queue0",
                "ComputeResources": [
                  {
                    "Name": "queue0-i0",
                    "InstanceType": "t2.micro",
                    "MinCount": 1,
                    "MaxCount": 11
                  }
                ],
                "Networking": {
                  "SubnetIds": ["subnet-08190f2e7fe1f140e"]
                }
              }
            ]
          }
        }
      }
    }
  }
}
STACK
}
