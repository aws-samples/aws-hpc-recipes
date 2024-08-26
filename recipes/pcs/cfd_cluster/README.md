# Example: CFD CLuster

## Info

Run OpenFOAM on PCS

## Usage

### Launch and configure a PCS cluster.

These instructions assume basic familiarity with PCS. If you have not worked with PCS before, we recommend working through the tutorial in [_Getting started with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) in the AWS PCS user guide before proceeding with this recipe.

To create and configure your cluster:
* Create or choose a VPC in `us-east-2` (Ohio).
* Create a cluster security group in `us-east-2` (Ohio) in your chosen VPC. You can do this manually or you can use [this CloudFormation template](assets/cluster-security-group.yaml)
* Create a small PCS cluster in `us-east-2` (Ohio) in your chosen VPC. When prompted to choose a subnet, select one that is in the `us-east-2b` availability zone. 
* Create an EFS filesystem in `us-east-2` (Ohio) in the same VPC where your cluster exists. Note the filesystem ID - you will need it later.
* Create a 1.2 TB FSx for Lustre filesystem in `us-east-2` (Ohio) in the same VPC where your cluster exists. When prompted to choose a subnet, select one that is in the `us-east-2b` availability zone. Note the filesystem ID - you will need it later.
* Create launch templates for the login and compute node groups in your cluster using the supplied [CloudFormation template](assets/cluster-launch-templates.yaml).
    * For `PublicSubnetId` and `PrivateSubnetId` choose subnets in the `us-east-2b` availability zone, in the VPC where your cluster exists.
    * Choose a cluster security group for `ClusterSecurityGroupId` and a security group that allows inbound SSH access for `SshSecurityGroupId`. If you used the provided template to create security groups, these will be named `cluster-${StackName}` and `inbound-ssh-${StackName}`.
    * Choose an SSH key for access to your instances for `SshKeyName`
    * Enter the filesystem ID for your EFS filesystem at `EfsFilesystemId`
    * Enter the filesystem ID for your FSx for Lustre filesystem at `FSxLustreFilesystemId`
    * Finish creating the CloudFormation stack.
* Create an IAM instance profile. You can do this manually or you can use [this CloudFormation template](assets/cluster-instance-profile.yaml).
* Create a login node group. Use the launch template named `login-${StackName}`. Name it `login`. Choose a `c6a` family instance type. Choose the same public subnet you specified when creating the launch template. Use the AWS PCS sample AMI. Set scaling to a minimum of 1 and maximum of 1 instances. 
* Create a compute node group. Use the launch template named `compute-1-${StackName}`. Name it `compute-1`, Choose the `hpc6a` instance type. Choose the same private subnet you specified when creating the launch template. Use the AWS PCS sample AMI. Set scaling to a minimum of 0 and maximum of 4 instances. 
* Once the `compute-1` node group reaching the **Active** status, create a queue named `compute` that includes the `compute-1` node group.
* Log into the EC2 instance managed by your `login` node group.
    * Confirm that `/home` and `/shared` are mounted network volumes
    * Confirm that Slurm is configured properly (run `sinfo`, `squeue`, etc.)

### Connect a standalone visualization node to the cluster

In this step, we will launch DCV workstation instance that mounts the same FSx for Lustre filesystem as used by the PCS cluster. 

To create and attach your DCV workstation:
* Upload the provided [CloudFormation template](assets/dcv-linux-node.yaml) to the CloudFormation console in the `us-east-2` region.
* Fill in all parameter values:
    * For `OperatingSystem` choose `AmazonLinux2-x64-Graphics-Intensive`
    * For `Password` provide a strong password. You will need this to log in to the instance web interface.
    * For `SshKeyName` select an SSH keypair.
    * For `AllowList` specify a range of IP addresses that connect to the instance. You can leave it as `0.0.0.0/0` to allow access from all IP addresses. 
    * For `StreamingPort`, enter `8443`.
    * For `DiskSize`, enter `50`
    * For `ClusterId` enter the ID of the PCS cluster you created earlier
    * For `PublicSubnetId`, select the same public subnet in `us-east-2` where your login node group is configured.
    * For `ClusterSecurityGroupId`, select the cluster security group for your PCS cluster
    * For `FSxLustreFilesystemId`, enter the filesystem ID for the FSx for Lustre filesystem you used to configure your PCS cluster.
    * For `FSxLustreMountDirectory`, enter `/shared` - this is the same as in your PCS cluster.
    * Finish creating the CloudFormation stack.
    * Find the HTTP address for the instance. Navigate to **Outputs** in the DCV stack you created. Find the output named **LinuxDcvURL**.
    * Navigate to the URL specifed by **LinuxDcvURL**. You will likely get a warning that the HTTPS connection is not secure. Ignore this and proceed to the web site. 
        * Sign into the DCV interface with the username **dcvuser** and the password you provided when you created the instance.
        * If you need to unlock the screen, use the same username and password.

### Install Spack on your cluster

In this step, we will install Spack. This is covered in more detail in the recipe [_Spack on PCS_](../spack_for_pcs/). 

Briefly, to install Spack in the network directory:
* Log into the instance that is managed by your `login` node group.
* Become `root`
* Download [`install.sh`](../spack_for_pcs/assets/install.sh) to the instance.
* Run this command: `./install.sh --directory /shared --slurm-directory /opt/aws/pcs/scheduler/slurm-23.11 --no-intel-compiler`
* Wait for it to complete. Log out and back into the instance. 

### Install OpenFOAM

* Log into the instance that is managed by your `login` node group.
* Become `root`
* Run `/shared/spack/bin/spack install openfoam-org@10` to install version 10 of OpenFOAM community edition.
* Wait for it to complete.
* Log out of root. 
* Verify that OpenFOAM is available - try `module load openfoam-org`.

### Install Paraview

In theory, you can use Spack to install Paraview. I have not, at the time of writing, been successful at this on AL2. So, we will just download it.
* Log into the instance that is managed by your `login` node group.
* Become `root`
* Change to the `/shared` directory (`cd /shared`).
* Download Paraview 5.12 `curl -skL "https://www.paraview.org/paraview-downloads/download.php?submit=Download&version=v5.12&type=binary&os=Linux&downloadFile=ParaView-5.12.1-MPI-Linux-Python3.10-x86_64.tar.gz" -o ParaView-5.12.1-MPI-Linux-Python3.10-x86_64.tar.gz`
* Unpack then delete the tarball `tar zxvf ParaView-5.12.1-MPI-Linux-Python3.10-x86_64.tar.gz && rm -f ParaView-5.12.1-MPI-Linux-Python3.10-x86_64.tar.gz`
* Log out of `root`
* Add `/shared/ParaView-5.12.1-MPI-Linux-Python3/bin` to your `$PATH`.

### Run the OpenFOAM motorBike demo

* Log into the instance that is managed by your `login` node group. Become the `ec2-user`.
* Load Spack with `. /shared/spack/share/spack/setup-env.sh` if it's not in your environment.
* Load OpenFOAM into the environment `module load openfoam-org`
* Set up the motorBike tutorial project

```shell
# Copy the tutorial file(s) into place
cp -R $FOAM_TUTORIALS/incompressible/simpleFoam/motorBike /shared/
cd /shared/motorBike
# Update the decomposition to work with 288 processors
sed -i 's/numberOfSubdomains  6;/numberOfSubdomains  288;/' system/decomposeParDict
sed -i 's/(3 2 1);/( 9 8 4);/' system/decomposeParDict
```

Now, write a job script:

```shell
cat << EOF > foam.sh
#!/bin/bash
#SBATCH --job-name=foam
#SBATCH --ntasks=288
#SBATCH --output=%x_%j.out
#SBATCH --partition=compute

date -u

. /shared/spack/share/spack/setup-env.sh
module load openfoam-org
module load openmpi
source \${FOAM_ETC}/bashrc
. \${WM_PROJECT_DIR:?}/bin/tools/RunFunctions

# Copy the geometry to the case directory
cp \${FOAM_TUTORIALS}/resources/geometry/motorBike.obj.gz constant/geometry/

# background mesh for Snappy
runApplication surfaceFeatures
runApplication blockMesh
# decompose and mesh
runApplication decomposePar -copyZero
runParallel snappyHexMesh -overwrite

# run the solver
runParallel patchSummary
runParallel potentialFoam
runParallel \$(getApplication)

runApplication reconstructParMesh -constant
runApplication reconstructPar -latestTime

date -u
EOF
```

Now, submit the job and wait for it to run `sbatch foam.sh`. When the job completes, check that it ran without error. The `foam_JOBID.out` file should resemble the following:

```
Mon Aug 26 19:37:44 UTC 2024
Running surfaceFeatures on /shared/motorBike
Running blockMesh on /shared/motorBike
Running decomposePar on /shared/motorBike
Running snappyHexMesh in parallel on /shared/motorBike using 288 processes
Running patchSummary in parallel on /shared/motorBike using 288 processes
Running potentialFoam in parallel on /shared/motorBike using 288 processes
Running simpleFoam in parallel on /shared/motorBike using 288 processes
Running reconstructParMesh on /shared/motorBike
Running reconstructPar on /shared/motorBike
Mon Aug 26 19:42:07 UTC 2024
```

Assuming that is the case, make the `motorBike` directory world-accessible (`chmod -R 777 /shared/motorBike`) so it can be read by the `dcvuser` on the DCV workstation node. 

