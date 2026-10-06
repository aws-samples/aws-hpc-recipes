# Complete example

Creates, in an existing VPC subnet:

1. A self-referencing security group.
2. A `SMALL` AWS PCS cluster with Slurm accounting and the Slurm REST API in
   `STANDARD` mode.
3. The accounting bootstrap: two QOS records (`normal`, `preempt`), two
   accounts (`research` with child `simulation`), two users, and their
   associations, all from structured Terraform values.
4. A compute node group (`min 0`, so no instances run until a job is
   submitted) and a queue named `batch` whose `DenyQos=preempt` custom setting
   references the QOS created in step 3.

Terraform orders steps 3 and 4 so the QOS exists before the queue is created.

## Prerequisites

- An existing VPC and subnet. The subnet must give a VPC Lambda a path to the
  PCS and Secrets Manager APIs, through a NAT gateway or interface VPC
  endpoints for `pcs` and `secretsmanager`. This example does not create
  endpoints because they are billed hourly; see the module README,
  "Networking", for the snippet if you need them.
- AWS credentials with permission to create PCS clusters, IAM roles, Lambda
  functions, security groups, and launch templates in that account.

## Run

```shell
cp terraform.tfvars.example terraform.tfvars   # edit region, vpc_id, subnet_id
terraform init
terraform apply
```

Cluster creation takes 10-20 minutes. The bootstrap Lambda runs once the
cluster is `ACTIVE` and normally finishes in a few seconds. On success the
`bootstrap_result` output shows the negotiated REST API version and how many
records were upserted:

```
bootstrap_result = {
  apiVersion = "v0.0.44"
  status     = "SUCCEEDED"
  upserted = {
    accounts     = 2
    associations = 4
    coordinators = 1
    qos          = 2
    users        = 2
    wckeys       = 0
  }
  ...
}
```

If the Lambda fails, `terraform apply` fails with the Lambda's error message
and nothing is recorded for the invocation. Fix the cause (most often a
security group or egress problem) and run `terraform apply` again; the
bootstrap is retried.

## Verify from a node

Launch a login node or submit a job to the `batch` queue, then on any cluster
node:

```shell
sacctmgr show qos format=Name,Priority,GrpJobs,MaxJobsPU,MaxTRESPerJob
sacctmgr show assoc tree format=Account,User,Share,DefQOS,QOS,MaxJobs
scontrol show partition batch | grep -o 'DenyQos=[^ ]*'
```

A job submitted with `--qos=preempt` to `batch` is rejected by Slurm.

## Change the accounting configuration

Edit the `qos`, `accounts`, `users`, or `associations` blocks in `main.tf` and
apply again. Changed and added records are upserted. Records you remove from
the configuration stay in Slurm; delete them with `sacctmgr` if needed.

## Cost

The cluster controller is billed while it exists, and compute nodes are billed
while jobs run. Run `terraform destroy` when you are done. Destroying the module
does not touch the Slurm database, but destroying the cluster removes it
entirely.

## Slurm version

The default `scheduler_version` is `26.05` (REST contract v0.0.45). Set it to
`25.11` for the v0.0.44 contract.
