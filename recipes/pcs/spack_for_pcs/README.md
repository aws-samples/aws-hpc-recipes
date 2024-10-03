# Spack on PCS

---
**Attention** As of 9/19/2024, the instructions in this recipe differ from how they are described in the HPC TechShorts video [Create and use a custom AMI for AWS Parallel Computing Service](https://www.youtube.com/watch?v=3ysMkZrDlGI). 

In that video:
1. The install script is named `install.sh`. Now it is named `postinstall.sh`
2. It refers to `--directory` as the option for setting Spack install location. This has been replaced with `--prefix`.
3. It refers to `--slurm-directory` as the option for specifying where Slurm is installed. This is no longer needed, as the installer script can now detect Slurm on a PCS-compatible AMI.
---

## Info

Configure Spack on AWS PCS via a shared filesystem or custom AMI. 

This recipe provides guidance and a resource for working with [Spack](https://spack.io) on PCS. It builds on work described in these HPC blog articles:
1. [Introducing the Spack Rolling Binary Cache hosted on AWS](https://aws.amazon.com/blogs/hpc/introducing-the-spack-rolling-binary-cache/)
2. [Install optimized software with Spack configs for AWS ParallelCluster](https://aws.amazon.com/blogs/hpc/install-optimized-software-with-spack-configs-for-aws-parallelcluster/)
3. [Spack Configs for AWS ParallelCluster](https://github.com/spack/spack-configs/tree/main/AWS/parallelcluster)

## Usage

### Shared filesysten

To install Spack on a shared filesystem: 
1. Set up a PCS cluster.
2. Add a static compute node group with at least one shared fileystem.  See [getting_started](../getting_started/) for examples of doing this with EFS and FSx for Lustre.
3. Log into an EC2 instance thatis managed by the static node group.
4. Download [`postinstall.sh`](https://raw.githubusercontent.com/spack/spack-configs/main/AWS/parallelcluster/postinstall.sh) to the instance. 
5. Make it executable (`chmod a+x postinstall.sh`).
6. Check out the options for the installer: `postinstall.sh -h`. Pay key attention to `--prefix` which determines where Spack will be installed. For example, if you specify `/shared`, Spack will be installed at `/shared/spack`.
7. Run the installer with administrative priveleges. 

Here is an example:

```shell
sudo postinstall.sh --prefix /shared
```

This will install Spack on a networked volume mounted at `/shared`. It will pick up the Slurm for AWS PCS installation at `/opt/aws/pcs/scheduler/slurm-*`. 

Monitor progress of the installer process with `tail -f /var/log/spack-install.log`. After installation has completed, you should be able to load Spack into your environment with `. /shared/spack/share/spack/setup-env.sh`. You can extend the shell environment for your PCS cluster users to automatically load the Spack environment. 

Use Spack to install additional software. It will be available on any instances that mount the shared filesystem.

### Custom AMI

To install Spack on a custom PCS AMI:
1. Familiarize yourself with the process for [building and using a custom AMI with PCS](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_ami_custom.html).
2. Launch a temporary instance with a suitable amount of storage. Keep in mind Spack and packages it installs can consume a lot of space. 
3. Install any other software you need on the AMI, such as the PCS agent, Slurm, EFA, and Lustre software.
4. Download [`postinstall.sh`](https://raw.githubusercontent.com/spack/spack-configs/main/AWS/parallelcluster/postinstall.sh) to the instance. 
5. Make it executable (`chmod a+x postinstall.sh`).
6. 6. Check out the options for the installer: `postinstall.sh -h`. Pay key attention to `--prefix` which determines where Spack will be installed. For example, if you specify `/opt`, Spack will be installed at `/opt/spack`.

Here is an example:

```shell
sudo postinstall.sh --prefix /opt 
```

This will install Spack on the instance's root volume at `/opt/spack`. It will pick up the Slurm installation at `/opt/aws/pcs/scheduler/slurm-*`. 

Monitor progress of the installer process with `tail -f /var/log/spack-install.log`. After installation has completed, log out and log back into the instance. The `spack` program should be in your `$PATH`.

Use Spack to install additional software, then create an AMI from the temporary instance. 
