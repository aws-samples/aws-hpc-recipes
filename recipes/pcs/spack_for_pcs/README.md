# Spack on PCS with shared filesystem

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
4. Download [`install.sh`](assets/install.sh) to the instance. 
5. Make it executable (`chmod a+x install.sh`).
6. Check out the options for the installer: `installer.sh -h`. Of these, only two are required:
    * `--directory` - The intended destination where you will install Spack. For example, if you specify `/shared`, Spack will be installed at `/shared/spack`.
    * `--slurm-directory` - The directory where Slurm has been installed. On a PCS-compatible AMI, you can find the Slurm installation under `/opt/aws/pcs`. An example would be `/opt/aws/pcs/scheduler/slurm-23.11`
7. Run the installer with administrative priveleges. 

Here is an example:

```shell
sudo install.sh --directory /shared --slurm-directory /opt/aws/pcs/scheduler/slurm-23.11
```

This will install Spack on a networked volume mounted at `/shared`. It will pick up the Slurm installation at `/opt/aws/pcs/scheduler/slurm-23.11`. 

Monitor progress of the installer process with `tail -f /var/log/spack-install.log`. After installation has completed, you should be able to load Spack into your environment with `. /shared/spack/share/spack/setup-env.sh`. You can extend the shell environment for your PCS cluster users to automatically load the Spack environment. 

Use Spack to install additional software. It will be available on any instances that mount the shared filesystem.

### Custom AMI

To install Spack on a custom PCS AMI:
1. Familiarize yourself with the process for [building and using a custom AMI with PCS](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_ami_custom.html).
2. Launch a temporary instance with a suitable amount of storage. Keep in mind Spack and packages it installs can consume a lot of space. 
3. Install any other software you need on the AMI, such as the PCS agent, Slurm, EFA, and Lustre software.
4. Download [`install.sh`](assets/install.sh) to the instance.
5. Make it executable (`chmod a+x install.sh`).
6. Check out the options for the installer: `installer.sh -h`. Of these, only two are required:
    * `--directory` - The intended destination where you will install Spack. For example, if you specify `/opt`, Spack will be installed at `/opt/spack`.
    * `--slurm-directory` - The directory where Slurm has been installed. On a PCS-compatible AMI, you can find the Slurm installation under `/opt/aws/pcs`. An example would be `/opt/aws/pcs/scheduler/slurm-23.11`
7. Run the installer with administrative priveleges. 

Here is an example:

```shell
sudo install.sh --directory /opt --slurm-directory /opt/aws/pcs/scheduler/slurm-23.11
```

This will install Spack on the instance's root volume at `/opt/spack`. It will pick up the Slurm installation at `/opt/aws/pcs/scheduler/slurm-23.11`. 

Monitor progress of the installer process with `tail -f /var/log/spack-install.log`. After installation has completed, log out and log back into the instance. The `spack` program should be in your `$PATH`.

Use Spack to install additional software, then create an AMI from the temporary instance. 
