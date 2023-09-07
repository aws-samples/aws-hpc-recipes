# AWS HPC Recipes

You can access recipe assets using HTTPS or S3 protocols.
* HTTPS URL - https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/VERSION/recipes/NAMESPACE/RECIPE/assets/
* S3 URL - s3://aws-hpc-recipes/VERSION/recipes/NAMESPACE/RECIPE/assets/

Generally, use `main` for the version, unless you need to pin to a specific tag or commit. If that's the case, replace `main` with a release tags such as `v1.0.0`. 

Here are example URLs for the CloudFormation launch template in the latest ParallelCluster recipe (**recipes/pcluster/latest**):
* HTTPS: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/latest/assets/launch.yaml
* S3: s3://aws-hpc-recipes/main/recipes/pcluster/latest/assets/launch.yaml

You can use the HTTPS link in a couple of contexts.
1. You can download the file it references
    * `curl -O HTTPS_URL`
2. If it's a Cloudformation template, you can import it into the CloudFormation console when creating a stack
3. You can embed it in a CloudFormation [quick-launch link](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stacks-quick-create-links.html).
    * `https://console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/create/review?templateURL=HTTPS_URL`

Many recipes in this repository feature quick-launch links. 

The S3 URL is useful anywhere you want to use native S3 commands for data access. 
* `aws s3 cp s3://aws-hpc-recipes/VERSION/recipes/NAMESPACE/RECIPE/assets/FILE.yaml .`

----

### :arrow_right: aws: General AWS (default)

*There are currently no recipes in this namespace.*
### :arrow_right: db: Database management

#### slurm_accounting_db ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Set up a replicated Amazon Aurora database that can support Slurm accounting.
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](db/slurm_accounting_db/README.md)
* **Default**: [assets/serverless-database.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/db/slurm_accounting_db/assets/serverless-database.yaml)

### :arrow_right: dir: Directory services

#### demo_managed_ad ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Stand up a basic AWS Managed Microsoft AD for use with AWS ParallelCluster.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](dir/demo_managed_ad/README.md)
* **Default**: [assets/main.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/main.yaml)

### :arrow_right: env: User environment

#### lmod ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-community-%2317202A) 

* **About**: Install Lmod alongside Environment modules
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](env/lmod/README.md)

#### spack ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-community-%2317202A) 

* **About**: Install and configure Spack on shared storage
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](env/spack/README.md)
* **Default**: [assets/postinstall.sh](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/env/spack/assets/postinstall.sh)

### :arrow_right: iam: Identity Access and Management

*There are currently no recipes in this namespace.*
### :arrow_right: ide: IDEs and GUIs

*There are currently no recipes in this namespace.*
### :arrow_right: net: Networking

#### hpc_simple ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-vpc-%23AAB7B8) 

* **About**: Networking configuration for HPC on AWS. Can use an existing VPC or create a new one.
* **Authors**: AWS HPC Engineering, Matthew Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](net/hpc_simple/README.md)
* **Default**: [assets/public-private.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_simple/assets/public-private.yaml)
#### hpc_large_scale ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-vpc-%23AAB7B8) 

* **About**: Networking configuration for large-scale HPC on AWS. Creates a new VPC.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](net/hpc_large_scale/README.md)
* **Default**: [assets/main.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_large_scale/assets/main.yaml)

### :arrow_right: pcluster: AWS ParallelCluster

#### multi_user ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-activedirectory-%23AAB7B8) ![tag](https://img.shields.io/badge/-secretsmanager-%237DCEA0) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Creates a multi-user instance of AWS ParallelCluster using AWS Managed AD as the directory service.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/multi_user/README.md)

#### pcui ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-cognito-%237DCEA0) ![tag](https://img.shields.io/badge/-lambda-%237DCEA0) 

* **About**: Create an AWS ParallelCluster with ParallelClusterUI to manage it.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/pcui/README.md)

#### multi_az ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Create a cluster that can launch instances in multiple Availability Zones
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/multi_az/README.md)

#### latest ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: 1-click AWS ParallelCluster 3.6.1 with support for network provisioning.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>, AWS HPC Engineering
* **Usage**: [README.md](pcluster/latest/README.md)
* **Default**: [assets/launch.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/latest/assets/launch.yaml)
#### slurm_accounting ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Create an instance of AWS ParallelCluster with Slurm accounting enabled, using Amazon RDS as the DBMS.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/slurm_accounting/README.md)


### :arrow_right: scheduler: HPC scheduler

*There are currently no recipes in this namespace.*
### :arrow_right: storage: Storage

#### efs_simple ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-efs-%237DCEA0) ![tag](https://img.shields.io/badge/-nfs-%23AAB7B8) 

* **About**: Create an Amazon EFS filesystem and mount targets in three Availability Zones.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/efs_simple/README.md)
* **Default**: [assets/main.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/efs_simple/assets/main.yaml)
#### fsx_lustre_s3_dra ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Demonstrates an FSx for Lustre filesystem with an S3 data repository association
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/fsx_lustre_s3_dra/README.md)

#### fsx_lustre ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) 

* **About**: Creates either a scratch or persistent FSxL filesystem and the relevant security groups for use with ParallelCluster.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/fsx_lustre/README.md)

#### fsx_openzfs ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-openzfs-%23AAB7B8) ![tag](https://img.shields.io/badge/-nfs-%23AAB7B8) 

* **About**: Provision an FSx for OpenZFS filesystem and relevant security groups for use with ParallelCluster
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/fsx_openzfs/README.md)
* **Default**: [assets/main.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_openzfs/assets/main.yaml)

