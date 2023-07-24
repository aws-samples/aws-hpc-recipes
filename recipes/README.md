# HPCDK Recipes

You can access recipe assets using HTTPS or S3 protocols.
* AWS S3 HTTP URL - https://hpcdk-on-aws.s3.us-east-2.amazonaws.com/VERSION/recipes/NAMESPACE/RECIPE/assets/
* AWS S3 protocol - s3://hpcdk-on-aws/VERSION/recipes/NAMESPACE/RECIPE/assets/

Generally, use `main` for the version, unless you need to pin to a specific HPCDK release. If that's the case, replace `main` with a release tags such as `v1.0.0`. 

### aws: General AWS (default)

*There are currently no recipes in this namespace.*
### db: Database management

#### slurm_accounting_db_aurora 

* **About**: Set up an Amazon Aurora database that can support Slurm accounting
* **Authors**: AWS HPC Engineering
* **Usage**: [README.md](recipes/aws/slurm_accounting_db_aurora/README.md)


### dir: Directory services

#### demo_managed_ad ![tag](https://img.shields.io/badge/-experimental-%23D9534F 

* **About**: Stand up a simple AWS Managed Microsoft AD
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/ad/demo_managed_ad/README.md)


### env: User environment

#### lmod ![tag](https://img.shields.io/badge/-experimental-%23D9534F 

* **About**: Install Lmod alongside Environment modules
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/env/lmod/README.md)

#### spack ![tag](https://img.shields.io/badge/-experimental-%23D9534F 

* **About**: Install and configure Spack on shared storage
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/env/spack/README.md)


### iam: Identity Access and Management

*There are currently no recipes in this namespace.*
### ide: IDEs and GUIs

#### cloud9 

* **About**: Cloud9 environment for working with HPC resources
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/cloud9/README.md)


### net: Networking

#### hpc_networking 

* **About**: Default HPC networking stacks from the ParallelCluster development team
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/hpc_networking/README.md)

#### hpc_networking_2az 

* **About**: HPC networking with support for two AZs
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/hpc_networking_2az/README.md)


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

#### fsxl_secgroup ![tag](https://img.shields.io/badge/-fsxl-%23AAB7B8 ![tag](https://img.shields.io/badge/-hpc-%23AAB7B8 ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900 

* **About**: Creates an FSxL filesystem and the Security Group needed for use with ParallelCluster
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/aws/fsxl_secgroup/README.md)

#### fsx_openzfs ![tag](https://img.shields.io/badge/-experimental-%23D9534F 

* **About**: Provision an FSx for OpenZFS filesystem for Pcluster
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/storage/fsx_openzfs/README.md)

#### efs ![tag](https://img.shields.io/badge/-experimental-%23D9534F 

* **About**: Provision an Amazon EFS filesystem
* **Authors**: Matt Vaughn <mwvaughn@amazon.com>
* **Usage**: [README.md](recipes/storage/efs/README.md)


