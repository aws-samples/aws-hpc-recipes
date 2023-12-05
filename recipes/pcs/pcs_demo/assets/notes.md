# NOTES

## Create Cluster

```shell
aws pcs --profile mwvaughn --region us-east-2 --endpoint-url https://gamma1.capi.us-east-2.skyb.alameda.aws.dev/ create-cluster --cluster-name cluster04 --scheduler type=SLURM,version=23.02 --networking subnetIds=subnet-0df859671b5061c6b,securityGroupIds=sg-0c9ad63cd7353902f
```

```shell
aws pcs --profile mwvaughn --region us-east-2 --endpoint-url https://gamma1.capi.us-east-2.skyb.alameda.aws.dev/ get-cluster --cluster-identifier cluster03
```

```json
{
    "cluster": {
        "name": "cluster03",
        "id": "582f16c2-1995-4b4b-8ece-1368f31bb72c",
        "createdAt": "2023-11-20T19:36:43.608093+00:00",
        "modifiedAt": "2023-11-20T19:36:43.608093+00:00",
        "scheduler": {
            "type": "SLURM",
            "version": "23.02"
        },
        "status": "CREATING",
        "networking": {
            "subnetIds": [
                "subnet-0df859671b5061c6b"
            ],
            "securityGroupIds": [
                "sg-0c9ad63cd7353902f"
            ]
        }
    }
}
```

## Launch Template

```json
{
  "NetworkInterfaces": [
    {
      "DeviceIndex": 0,
      "SubnetId": "subnet-0c292cf5104a9aad6",
      "Groups": ["sg-0021f1d26d18db531"]
    }
  ]
}
```

```
aws pcs --profile mwvaughn --region us-east-2 --endpoint-url https://gamma1.capi.us-east-2.skyb.alameda.aws.dev/ delete-cluster --cluster-identifier cluster03
```

## Create Login Node Group

```shell
aws pcs --profile mwvaughn --region us-east-2 --endpoint-url https://gamma1.capi.us-east-2.skyb.alameda.aws.dev/ create-compute-node-group --cluster-identifier cluster04 --compute-node-group-name login-01 --ami-type AL2 --subnet-ids subnet-06b022299c7290a36 --custom-launch-template id=lt-08c8f7f3718d957a6,version=1 --iam-instance-profile arn=arn:aws:iam::609783872011:instance-profile/SkybridgeBasicInstanceProfile --scaling-config minInstanceCount=1,maxInstanceCount=1 --instances instanceType=t3.large
```

```shell
aws pcs --profile mwvaughn --region us-east-2 --endpoint-url https://gamma1.capi.us-east-2.skyb.alameda.aws.dev/ get-compute-node-group --cluster-identifier cluster04 --compute-node-group-identifier
login-01
```

```json
{
    "computeNodeGroup": {
        "name": "login-01",
        "id": "8fa7db68-ddd4-4f84-ac89-0cdb51b12ca2",
        "clusterId": "2d71cb25-da90-4c54-94f0-dc25c55889d4",
        "createdAt": "2023-11-21T17:38:34.313903+00:00",
        "modifiedAt": "2023-11-21T17:38:34.313903+00:00",
        "status": "CREATING",
        "amiType": "AL2",
        "subnetIds": [
            "subnet-06b022299c7290a36"
        ],
        "customLaunchTemplate": {
            "id": "lt-08c8f7f3718d957a6",
            "version": "1"
        },
        "iamInstanceProfile": {
            "arn": "arn:aws:iam::609783872011:instance-profile/SkybridgeBasicInstanceProfile"
        },
        "scalingConfig": {
            "minInstanceCount": 1,
            "maxInstanceCount": 1
        },
        "instances": [
            {
                "instanceType": "t3.large"
            }
        ]
    }
}
```

## Create Queue

```shell
aws pcs --profile mwvaughn --region us-east-2 --endpoint-url https://gamma1.capi.us-east-2.skyb.alameda.aws.dev/ create-queue --queue-name demo1 --cluster-identifier cluster04 --compute-node-group-configurations computeNodeGroupId=login-01
{
    "queue": {
        "name": "demo1",
        "id": "f72b9a0b-f2b1-480b-b3f7-b8b8bb19520b",
        "clusterId": "2d71cb25-da90-4c54-94f0-dc25c55889d4",
        "createdAt": "2023-11-21T20:57:28.442244+00:00",
        "modifiedAt": "2023-11-21T20:57:28.442244+00:00",
        "status": "CREATING",
        "computeNodeGroupConfigurations": [
            {
                "computeNodeGroupId": "login-01"
            }
        ]
    }
}
```

```shell
aws pcs --profile mwvaughn --region us-east-2 --endpoint-url https://gamma1.capi.us-east-2.skyb.alameda.aws.dev/ create-compute-node-group --cluster-identifier cluster04 --compute-node-group-name login-02 --ami-type AL2 --subnet-ids subnet-0678eccd7a1f34212 --custom-launch-template id=lt-08c8f7f3718d957a6,version=1 --iam-instance-profile arn=arn:aws:iam::609783872011:instance-profile/SkybridgeBasicInstanceProfile --scaling-config minInstanceCount=2,maxInstanceCount=2 --instances instanceType=t3.large

```
