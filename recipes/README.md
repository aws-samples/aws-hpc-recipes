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

#### hpc_networking ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Default HPC networking stacks from the AWS ParallelCluster development team
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](recipes//hpc_networking/README.md)

#### hpc_networking_2az ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-experimental-%23D9534F) 

* **About**: HPC networking with support for two Availability Zones.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes//hpc_networking_2az/README.md)


### pcluster: AWS ParallelCluster

#### parallelcluster_ui 

* **About**: Installs PCUI in the customers account
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](recipes/aws/parallelcluster_ui/README.md)

#### pcluster_2az_sacct 

* **About**: Launch ParallelCluster supporting 2 AZ and Slurm accounting.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/pcluster_2az_sacct/README.md)

#### pcluster_2az 

* **About**: ParallelCluster supporting 2 AZ
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/pcluster_2az/README.md)

#### pcluster_2az_fsxl_scratch 

* **About**: ParallelCluster supporting 2 AZ with FSxLustre SCRATCH volume
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/pcluster_2az_fsxl_scratch/README.md)

#### pcluster 

* **About**: 1-click Pcluster with network provisioning support.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/pcluster/README.md)

#### pcluster_2az_sacct_pcui 

* **About**: ParallelCluster supporting 2 AZ and Slurm accounting, managed by PCUI.
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/pcluster_2az_sacct_pcui/README.md)


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


