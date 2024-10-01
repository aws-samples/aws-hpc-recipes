# HPC Recipes for AWS

This page shows [all available recipes](#recipe-list). They are organized by theme (e.g. `Database management` and `Networking`). Each recipe also has tags that indicate the key technologies (i.e. `parallelcluster` and `rds`) it references. 

## Making use of recipes

You can use an HPC Recipe for AWS in several ways:

* **Learn from it.** Read the README file and inspect its `assets` directory to understand how it works. 
* **Launch resources with it.** Navigate to its README page and follow the instructions. There is often a quick-launch link to the AWS CloudFormation console.
* **Incorporate it.** Recipe assets are permissively licensed so you can use them in your own builds. You can also [bring assets in by URL](#incorporating-recipe-assets)

## Recipe List

### :arrow_right: aws: General AWS (default)

*There are currently no recipes in this namespace.*

### :arrow_right: db: Database management

#### slurm_accounting_db ![tag](https://img.shields.io/badge/-aurora=-%23AAB7B8) ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-serverless-%23AAB7B8) 

* **About**: Set up a replicated Amazon Aurora database that can support Slurm accounting.
* **Usage**: [README.md](db/slurm_accounting_db/README.md)


### :arrow_right: dir: Directory services

#### demo_managed_ad ![tag](https://img.shields.io/badge/-activedirectory-%23AAB7B8) ![tag](https://img.shields.io/badge/-secretsmanager-%237DCEA0) 

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

#### hpc_basic ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-vpc-%23AAB7B8) 

* **About**: Networking configuration for HPC on AWS. Can use an existing VPC or create a new one.
* **Usage**: [README.md](net/hpc_basic/README.md)

#### hpc_large_scale ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-vpc-%23AAB7B8) 

* **About**: Networking configuration for large-scale HPC on AWS. Creates a new VPC.
* **Usage**: [README.md](net/hpc_large_scale/README.md)


### :arrow_right: pcluster: AWS ParallelCluster

#### decoupled_storage ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-efs-%237DCEA0) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-pcluster-%23AAB7B8) 

* **About**: Demonstrate decoupled shared storage using Amazon EFS.
* **Usage**: [README.md](pcluster/decoupled_storage/README.md)

#### isolated-clusters ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Provides templates to configure AWS ParallelCluster for isolated environments/those with no Internet access.
* **Usage**: [README.md](pcluster/isolated-clusters/README.md)

#### latest ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Quick demo of the latest ParallelCluster release
* **Usage**: [README.md](pcluster/latest/README.md)

#### login_nodes ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Demonstrates the new Login Nodes feature in ParallelCluster 3.7.2
* **Usage**: [README.md](pcluster/login_nodes/README.md)

#### login_nodes_ami_for_res ![tag](https://img.shields.io/badge/-pcluster-%23AAB7B8) ![tag](https://img.shields.io/badge/-res-%237DCEA0) ![tag](https://img.shields.io/badge/-ssm-%23AAB7B8) 

* **About**: Create an AMI of a ParallelCluster LoginNode compatible with Research and Engineering Studio
* **Usage**: [README.md](pcluster/login_nodes_ami_for_res/README.md)

#### multi_az ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Create a cluster that can launch instances in multiple Availability Zones
* **Usage**: [README.md](pcluster/multi_az/README.md)

#### multi_user ![tag](https://img.shields.io/badge/-activedirectory-%23AAB7B8) ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-secretsmanager-%237DCEA0) 

* **About**: Creates a multi-user instance of AWS ParallelCluster using AWS Managed AD as the directory service.
* **Usage**: [README.md](pcluster/multi_user/README.md)

#### pcui ![tag](https://img.shields.io/badge/-cognito-%237DCEA0) ![tag](https://img.shields.io/badge/-lambda-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Create an AWS ParallelCluster with ParallelClusterUI to manage it.
* **Usage**: [README.md](pcluster/pcui/README.md)

#### slurm_accounting ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) 

* **About**: Create an instance of AWS ParallelCluster with Slurm accounting enabled, using Amazon RDS as the DBMS.
* **Usage**: [README.md](pcluster/slurm_accounting/README.md)

#### slurm_accounting_with_email ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-email-%23AAB7B8) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-rds-%237DCEA0) ![tag](https://img.shields.io/badge/-sms-%23AAB7B8) 

* **About**: Create an instance of AWS ParallelCluster with Slurm accounting enabled and e-mail notifications using Slurm-Mail, using Amazon RDS as the DBMS.
* **Usage**: [README.md](pcluster/slurm_accounting_with_email/README.md)

#### stig ![tag](https://img.shields.io/badge/-ec2imagebuilder-%23AAB7B8) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-systemsmanager-%23AAB7B8) 

* **About**: Includes files to accelerate STIG compliance for Parallelcluster images as well as scripts to verify OSCAP results
* **Usage**: [README.md](pcluster/stig/README.md)

#### try_hpc6a ![tag](https://img.shields.io/badge/-hpc6a-%23AAB7B8) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-x86_64-%23AAB7B8) 

* **About**: Create a ParallelCluster system to try out Hpc6a instances.
* **Usage**: [README.md](pcluster/try_hpc6a/README.md)

#### try_hpc6id ![tag](https://img.shields.io/badge/-hpc6id-%23AAB7B8) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-x86_64-%23AAB7B8) 

* **About**: Create a ParallelCluster system to try out Hpc6id instances.
* **Usage**: [README.md](pcluster/try_hpc6id/README.md)

#### try_hpc7a ![tag](https://img.shields.io/badge/-hpc7a-%23AAB7B8) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-x86_64-%23AAB7B8) 

* **About**: Create a ParallelCluster system to try out Hpc7a instances.
* **Usage**: [README.md](pcluster/try_hpc7a/README.md)

#### try_hpc7g ![tag](https://img.shields.io/badge/-aarch64-%23AAB7B8) ![tag](https://img.shields.io/badge/-graviton-%237DCEA0) ![tag](https://img.shields.io/badge/-hpc7g-%23AAB7B8) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) 

* **About**: Create a ParallelCluster system to try out Hpc7g instances.
* **Usage**: [README.md](pcluster/try_hpc7g/README.md)

#### try_trn1 ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-neuronsdk-%23AAB7B8) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-trainium-%23AAB7B8) 

* **About**: Create a ParallelCluster system to try out Trn1 instances.
* **Usage**: [README.md](pcluster/try_trn1/README.md)


### :arrow_right: res: Research and Engineering Studio on AWS

#### entra_id ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-entra_id-%23AAB7B8) ![tag](https://img.shields.io/badge/-identity-%23AAB7B8) ![tag](https://img.shields.io/badge/-res-%237DCEA0) 

* **About**: Set up Entra ID with RES
* **Usage**: [README.md](res/entra_id/README.md)

#### res_demo_env ![tag](https://img.shields.io/badge/-ad-%23AAB7B8) ![tag](https://img.shields.io/badge/-cognito-%237DCEA0) ![tag](https://img.shields.io/badge/-dcv-%23AAB7B8) ![tag](https://img.shields.io/badge/-ec2-%23AAB7B8) ![tag](https://img.shields.io/badge/-efs-%237DCEA0) ![tag](https://img.shields.io/badge/-res-%237DCEA0) ![tag](https://img.shields.io/badge/-sso-%23AAB7B8) 

* **About**: Research and Engineering Studio (RES) on AWS demo environment
* **Usage**: [README.md](res/res_demo_env/README.md)


### :arrow_right: security: Security configuration

#### public_certs ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-route53-%23AAB7B8) ![tag](https://img.shields.io/badge/-secretsmanager-%237DCEA0) ![tag](https://img.shields.io/badge/-vpc-%23AAB7B8) 

* **About**: Certificate creation for public domain. Creates secrets for pem/key files for a public cert for a Route53 owned domain.
* **Usage**: [README.md](security/public_certs/README.md)


### :arrow_right: scheduler: HPC scheduler

*There are currently no recipes in this namespace.*

### :arrow_right: storage: Storage

#### efs_simple ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-efs-%237DCEA0) ![tag](https://img.shields.io/badge/-nfs-%23AAB7B8) 

* **About**: Create an Amazon EFS filesystem and mount targets in three Availability Zones.
* **Usage**: [README.md](storage/efs_simple/README.md)

#### fsx_lustre ![tag](https://img.shields.io/badge/-core-%23146EB4) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) 

* **About**: Creates either a scratch or persistent FSxL filesystem and the relevant security groups for use with ParallelCluster.
* **Usage**: [README.md](storage/fsx_lustre/README.md)

#### fsx_lustre_s3_dra ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-lustre-%23AAB7B8) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) 

* **About**: Demonstrates an FSx for Lustre filesystem with an S3 data repository association
* **Usage**: [README.md](storage/fsx_lustre_s3_dra/README.md)

#### fsx_openzfs ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-nfs-%23AAB7B8) ![tag](https://img.shields.io/badge/-openzfs-%23AAB7B8) 

* **About**: Provision an FSx for OpenZFS filesystem and relevant security groups for use with ParallelCluster
* **Usage**: [README.md](storage/fsx_openzfs/README.md)

#### mountpoint_s3 ![tag](https://img.shields.io/badge/-beta-%23800080) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) 

* **About**: Configure AWS ParallelCluster to mount S3 buckets to directories using mountpoint-s3
* **Usage**: [README.md](storage/mountpoint_s3/README.md)

#### s3_demo ![tag](https://img.shields.io/badge/-s3-%237DCEA0) 

* **About**: Create an Amazon S3 bucket using CloudFormation.
* **Usage**: [README.md](storage/s3_demo/README.md)


### :arrow_right: training: Teaching and training recipes

#### try_recipes_1 ![tag](https://img.shields.io/badge/-cloudformation-%237DCEA0) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) 

* **About**: Cluster example using manual configuration.
* **Usage**: [README.md](training/try_recipes_1/README.md)

#### try_recipes_2 ![tag](https://img.shields.io/badge/-cloudformation-%237DCEA0) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) 

* **About**: Cluster example using CloudFormation imports.
* **Usage**: [README.md](training/try_recipes_2/README.md)

#### try_recipes_3 ![tag](https://img.shields.io/badge/-cloudformation-%237DCEA0) ![tag](https://img.shields.io/badge/-fsx-%237DCEA0) ![tag](https://img.shields.io/badge/-parallelcluster-%23FF9900) ![tag](https://img.shields.io/badge/-s3-%237DCEA0) 

* **About**: Cluster example using nested CloudFormation stacks.
* **Usage**: [README.md](training/try_recipes_3/README.md)



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
