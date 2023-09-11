# HPC Recipes for AWS

This page shows [all available recipes](#recipe-list). They are organized by theme (e.g. `Database management` and `Networking`). Each recipe also has tags that indicate the key technologies (i.e. `parallelcluster` and `rds`) it references. 

## Making use of recipes

You can use an AWS HPC recipe in several ways:

* **Learn from it.** Read the README file and inspect its `assets` directory to understand how it works. 
* **Launch resources with it.** Navigate to its README page and follow the instructions. There is often a quick-launch link to the AWS CloudFormation console.
* **Incorporate it.** Recipe assets are permissively licensed so you can use them in your own builds. You can also [bring assets in by URL](#incorporating-recipe-assets)

## Recipe List

### :arrow_right: aws: General AWS (default)

*There are currently no recipes in this namespace.*

### :arrow_right: db: Database management

#### slurm_accounting_db ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Set up a replicated Amazon Aurora database that can support Slurm accounting.
* **Usage**: [README.md](db/slurm_accounting_db/README.md)


### :arrow_right: dir: Directory services

#### demo_managed_ad ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-activedirectory-%23AAB7B8) ![tag](https://img.shields.io/badge/-secretsmanager-%237DCEA0) 

* **About**: Stand up a basic AWS Managed Microsoft AD for use with AWS ParallelCluster.
* **Usage**: [README.md](dir/demo_managed_ad/README.md)


### :arrow_right: env: User environment

#### spack ![tag](https://img.shields.io/badge/-community-%2317202A) 

* **About**: Install and configure Spack + Spack configs on shared storage
* **Usage**: [README.md](env/spack/README.md)


### :arrow_right: iam: Identity Access and Management

*There are currently no recipes in this namespace.*

### :arrow_right: ide: IDEs and GUIs

*There are currently no recipes in this namespace.*

### :arrow_right: net: Networking

#### hpc_large_scale ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-vpc-%23AAB7B8) 

* **About**: Networking configuration for large-scale HPC on AWS. Creates a new VPC.
* **Usage**: [README.md](net/hpc_large_scale/README.md)

#### hpc_simple ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-vpc-%23AAB7B8) 

* **About**: Networking configuration for HPC on AWS. Can use an existing VPC or create a new one.
* **Usage**: [README.md](net/hpc_simple/README.md)


### :arrow_right: pcluster: AWS ParallelCluster

#### latest ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Quick demo of the latest ParallelCluster release
* **Usage**: [README.md](pcluster/latest/README.md)

#### login_nodes ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Demonstrates the new Login Nodes feature in ParallelCluster 3.7.0
* **Usage**: [README.md](pcluster/login_nodes/README.md)

#### multi_az ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Create a cluster that can launch instances in multiple Availability Zones
* **Usage**: [README.md](pcluster/multi_az/README.md)

#### multi_user ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-activedirectory-%23AAB7B8) ![tag](https://img.shields.io/badge/-secretsmanager-%237DCEA0) ![tag](https://img.shields.io/badge/-beta-%23800080) 

* **About**: Creates a multi-user instance of AWS ParallelCluster using AWS Managed AD as the directory service.
* **Usage**: [README.md](pcluster/multi_user/README.md)

#### pcui ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-cognito-%237DCEA0) ![tag](https://img.shields.io/badge/-lambda-%237DCEA0) 

* **About**: Create an AWS ParallelCluster with ParallelClusterUI to manage it.
* **Usage**: [README.md](pcluster/pcui/README.md)

#### slurm_accounting ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) ![tag](https://img.shields.io/badge/-core-%23146EB4) 

* **About**: Create an instance of AWS ParallelCluster with Slurm accounting enabled, using Amazon RDS as the DBMS.
* **Usage**: [README.md](pcluster/slurm_accounting/README.md)


### :arrow_right: scheduler: HPC scheduler

*There are currently no recipes in this namespace.*

### :arrow_right: storage: Storage

#### efs_simple ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-efs-%237DCEA0) ![tag](https://img.shields.io/badge/-nfs-%23AAB7B8) 

* **About**: Create an Amazon EFS filesystem and mount targets in three Availability Zones.
* **Usage**: [README.md](storage/efs_simple/README.md)

#### fsx_lustre ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) 

* **About**: Creates either a scratch or persistent FSxL filesystem and the relevant security groups for use with ParallelCluster.
* **Usage**: [README.md](storage/fsx_lustre/README.md)

#### fsx_lustre_s3_dra ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) ![tag](https://img.shields.io/badge/-beta-%23800080) 

* **About**: Demonstrates an FSx for Lustre filesystem with an S3 data repository association
* **Usage**: [README.md](storage/fsx_lustre_s3_dra/README.md)

#### fsx_openzfs ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-openzfs-%23AAB7B8) ![tag](https://img.shields.io/badge/-nfs-%23AAB7B8) 

* **About**: Provision an FSx for OpenZFS filesystem and relevant security groups for use with ParallelCluster
* **Usage**: [README.md](storage/fsx_openzfs/README.md)



---
## Incorporating recipe assets

You can access recipe assets using HTTPS or S3 protocols. They are mirrored to an S3 bucket so they can used with AWS CloudFormation. 

Here are example URLs for the CloudFormation launch template for the "latest" ParallelCluster recipe (**recipes/pcluster/latest**):
* **HTTPS Template**: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/latest/assets/launch.yaml
* **S3 Template**: s3://aws-hpc-recipes/main/recipes/pcluster/latest/assets/launch.yaml

In both URLs, `/main/` is the HPC Recipes on AWS version. At present, the only supported version is **main**. 

You can use the HTTPS link in a couple of contexts.
1. You can download the file it references
    * `curl -O HTTPS_URL`
2. If it's a Cloudformation template, you can import it into the CloudFormation console when creating a stack
3. You can embed it in a CloudFormation [quick-launch link](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-console-create-stacks-quick-create-links.html).
    * **Template**: `https://console.aws.amazon.com/cloudformation/home?region=REGION#/stacks/create/review?templateURL=HTTPS_URL`

The S3 URL is useful anywhere you want to use native S3 commands for data access. 
* **Template**: `aws s3 cp s3://aws-hpc-recipes/main/recipes/NAMESPACE/RECIPE/assets/FILE.yaml .`
