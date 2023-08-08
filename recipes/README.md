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
* **Usage**: [README.md](recipes//slurm_accounting_db/README.md)


### dir: Directory services

#### demo_managed_ad ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Stand up a basic AWS Managed Microsoft AD for use with AWS ParallelCluster.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//demo_managed_ad/README.md)


### env: User environment

#### lmod ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-community-%2317202A) 

* **About**: Install Lmod alongside Environment modules
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//lmod/README.md)

#### spack ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-community-%2317202A) 

* **About**: Install and configure Spack on shared storage
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//spack/README.md)


### iam: Identity Access and Management

*There are currently no recipes in this namespace.*
### ide: IDEs and GUIs

#### cloud9 ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Cloud9 environment for working with HPC resources
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//cloud9/README.md)


### net: Networking

#### simple ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Default HPC networking stacks from the AWS ParallelCluster development team
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](recipes//simple/README.md)

#### hpc_large_scale ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Setup for large scale computations on AWS across multiple regions
* **Authors**: Pierre-Yves Aquilanti <pierreya@amazon.com>, Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//hpc_large_scale/README.md)

#### hpc_networking_2az ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: HPC networking with support for two Availability Zones.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//hpc_networking_2az/README.md)


### pcluster: AWS ParallelCluster

#### parallelcluster_ui ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Deploy AWS ParallelCluster UI in your customer account.
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](recipes//parallelcluster_ui/README.md)

#### pcluster_2az ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Deploy AWS ParallelCluster with a queue that leverages two availability zones for extra capacity.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//pcluster_2az/README.md)

#### latest ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: 1-click AWS ParallelCluster 3.6.1 with support for network provisioning.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>, AWS HPC Engineering
* **Usage**: [README.md](recipes//latest/README.md)

#### pcluster_sacct_pcui ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) 

* **About**: Launch AWS ParallelCluster with Slurm accounting, managed by the ParallelCluster UI.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//pcluster_sacct_pcui/README.md)

#### pcluster_lustre_scratch ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) 

* **About**: Deploy AWS ParallelCluster with an Amazon FSx for Lustre scratch volume
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//pcluster_lustre_scratch/README.md)

#### pcluster_sacct ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) 

* **About**: Launch AWS ParallelCluster with support for Slurm accounting.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//pcluster_sacct/README.md)


### scheduler: HPC scheduler

*There are currently no recipes in this namespace.*
### storage: Storage

#### fsx_lustre ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Creates an FSxL filesystem and relevant security groups for use with ParallelCluster.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//fsx_lustre/README.md)

#### simple_efs ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: Provision a basic Amazon EFS filesystem
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//simple_efs/README.md)

#### fsx_openzfs ![tag](https://img.shields.io/badge/-community-%2317202A) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) ![tag](https://img.shields.io/badge/-efs-%237DCEA0) 

* **About**: Provision an FSx for OpenZFS filesystem and relevant security groups for use with ParallelCluster
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//fsx_openzfs/README.md)


