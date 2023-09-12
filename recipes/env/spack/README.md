# Install Spack + Spack Configs on AWS ParallelCluster

## Info

This recipe installs Spack and performance-optimizing Spack configs developed by the AWS HPC Performance Engineering team onto the shared storage of a ParallelCluster system. 

## Usage

Configure the script at [assets/postinstall.sh](assets/postinstall.sh) as a ParallelCluster custom bootstrap action on the cluster head node. Here are two example configurations.

First, you can include the script in a ParallelCluster configuration file via its HPC recipes on AWS HTTPS URL. 

```yaml
---
HeadNode:
    CustomActions:
        OnNodeConfigured:
            Script: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/env/spack/assets/postinstall.sh
```

Second, you can incorporate the same URL into a ParallelCluster CloudFormation custom resource to install Spack on an IaC-managed cluster. 

```yaml
Resources:
    PclusterCluster:
        ClusterConfiguration:
            HeadNode:
                CustomActions:
                    OnNodeConfigured:
                        Script: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/env/spack/assets/postinstall.sh
```

In either case, Spack will install into the first shared directory it finds. If it cannot find a shared directory, it will install in `/home/ec2-user/spack`. 

**Note**: These examples are excerpts of the full ParallelCluster configuration or CloudFormation custom resource. They are meant to show where to place the `OnNodeConfigured` stanza in the respective configurations. 

## References

* For a deep-dive into Spack on ParallelCluster, consult the [AWS HPC blog](https://aws.amazon.com/blogs/hpc/install-optimized-software-with-spack-configs-for-aws-parallelcluster/).
* For details of how Spack configs are implemented, consult the [spack/spack-configs GitHub repo](https://github.com/spack/spack-configs/tree/main/AWS/parallelcluster).

## Cost Estimate

The only cost incurred by this recipe should be charges arising from installing Spack on an a shared EFS volume. Other filesystems have provisioned capacity, so the Spack installation won't directly lead to charges.
