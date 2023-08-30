# HPCDK Recipes

You can access recipe assets using HTTPS or S3 protocols.
* AWS S3 HTTP URL - https://hpcdk-on-aws.s3.us-east-2.amazonaws.com/VERSION/recipes/NAMESPACE/RECIPE/assets/
* AWS S3 protocol - s3://hpcdk-on-aws/VERSION/recipes/NAMESPACE/RECIPE/assets/

Generally, use `main` for the version, unless you need to pin to a specific HPCDK release. If that's the case, replace `main` with a release tags such as `v1.0.0`. 

### aws: General AWS (default)

*There are currently no recipes in this namespace.*
### db: Database management

#### slurm_accounting_db ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Set up a replicated Amazon Aurora database that can support Slurm accounting.
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](db/slurm_accounting_db/README.md)
* **Default**: [assets/serverless-database.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/db/slurm_accounting_db/assets/serverless-database.yaml)

### dir: Directory services

#### demo_managed_ad ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Stand up a basic AWS Managed Microsoft AD for use with AWS ParallelCluster.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](dir/demo_managed_ad/README.md)
* **Default**: [assets/main.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/main.yaml)

### env: User environment

#### lmod ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-community-%2317202A) 

* **About**: Install Lmod alongside Environment modules
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](env/lmod/README.md)

#### spack ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-community-%2317202A) 

* **About**: Install and configure Spack on shared storage
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](env/spack/README.md)
* **Default**: [assets/postinstall.sh](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/env/spack/assets/postinstall.sh)

### iam: Identity Access and Management

*There are currently no recipes in this namespace.*
### ide: IDEs and GUIs

#### cloud9 ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Cloud9 environment for working with HPC resources
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](ide/cloud9/README.md)
* **Default**: [assets/cloud9.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/ide/cloud9/assets/cloud9.yaml)

### net: Networking

#### simple ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Default HPC networking stacks from the AWS ParallelCluster development team
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](net/simple/README.md)
* **Default**: [assets/public-private.cfn.json](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/simple/assets/public-private.cfn.json)
#### hpc_large_scale ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Setup for large scale computations on AWS across multiple regions
* **Authors**: Pierre-Yves Aquilanti <pierreya@amazon.com>, Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](net/hpc_large_scale/README.md)
* **Default**: [assets/main.yml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_large_scale/assets/main.yml)
#### hpc_networking_2az ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: HPC networking with support for two Availability Zones.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](net/hpc_networking_2az/README.md)
* **Default**: [assets/public-private.cfn.yml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_networking_2az/assets/public-private.cfn.yml)

### pcluster: AWS ParallelCluster

#### multi_user ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-activedirectory-%23AAB7B8) ![tag](https://img.shields.io/badge/-secretsmanager-%23AAB7B8) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Creates a multi-user instance of AWS ParallelCluster using AWS Managed AD as the directory service.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/multi_user/README.md)

#### pcui ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-cognito-%23AAB7B8) ![tag](https://img.shields.io/badge/-lambda-%23AAB7B8) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Create an AWS ParallelCluster with ParallelClusterUI to manage it.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/pcui/README.md)

#### multi_az ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Create a cluster that can launch instances in multiple Availability Zones
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/multi_az/README.md)

#### latest ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: 1-click AWS ParallelCluster 3.6.1 with support for network provisioning.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>, AWS HPC Engineering
* **Usage**: [README.md](pcluster/latest/README.md)
* **Default**: [assets/launch.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/latest/assets/launch.yaml)
#### slurm_accounting ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Create an instance of AWS ParallelCluster with Slurm accounting enabled, using Amazon RDS as the DBMS.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/slurm_accounting/README.md)

#### pcluster_lustre_scratch ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) 

* **About**: Deploy AWS ParallelCluster with an Amazon FSx for Lustre scratch volume
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](pcluster/pcluster_lustre_scratch/README.md)
* **Default**: [assets/launch.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/pcluster_lustre_scratch/assets/launch.yaml)

### scheduler: HPC scheduler

*There are currently no recipes in this namespace.*
### storage: Storage

#### fsx_lustre_s3_dra ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Demonstrates an FSx for Lustre filesystem with an S3 data repository association
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/fsx_lustre_s3_dra/README.md)

#### fsx_lustre ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Creates an FSxL filesystem and relevant security groups for use with ParallelCluster.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/fsx_lustre/README.md)

#### simple_efs ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Provision a basic Amazon EFS filesystem
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/simple_efs/README.md)
* **Default**: [assets/main.yml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/simple_efs/assets/main.yml)
#### fsx_openzfs ![tag](https://img.shields.io/badge/-community-%2317202A) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-efs-%237DCEA0) 

* **About**: Provision an FSx for OpenZFS filesystem and relevant security groups for use with ParallelCluster
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](storage/fsx_openzfs/README.md)
* **Default**: [assets/main.yaml](https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_openzfs/assets/main.yaml)

