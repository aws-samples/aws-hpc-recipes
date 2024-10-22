# Install and configure EESSI on AWS ParallelCluster

This recipe installs the EESSI software stack locally to the VM at /cvmfs and performs some other optional actions:

* Inject NVIDIA drivers and libraries into the EESSI stack, to allow EESSI software to use the host NVIDIA GPU.
* Inject into EESSI host modified MPI libraries that are forced to use the hosts's `libfabric.so`, `libefa.so` and `libibverbs.so` libraries supplied by ParallelCluster OS images.
* Install a squid proxy server in the head node that caches the EESSI software for fast availability. The compute nodes check if there is a squid cache functioning in the head hode. If there is, CVMFS is configured to use the cache.

**Requirements**

* AWS ParallelCluster v3


## Deployment

Include the script assets/postinstall.sh as part of the CustomActions of the head and compute nodes in the ParallelCluster configuration:

```yaml
HeadNode:
    CustomActions:
        OnNodeConfigured:
            Script: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/env/eessi/assets/postinstall.sh
```

The script provides a set of options to customize its behavior:

* `-x`: Set xtrace bash option for debugging.
* `-v`: Set verbose bash option for debugging.
* `-nogpu`: Do not inject host GPU drivers and libraries into EESSI.
* `-noefa`: Do not inject host EFA and MPI libraries into EESSI.
* `-nocache`: Do not setup a Squid Proxy cache for CVMFS Stratum 1. For a HeadNode it skips the installation of a Squid server and for a compute node it skips configuring CVMFS to go through the proxy of the HeadNode.
* `-noptrace`: Do not disable ptrace protection if is enabled by default. By default, ptrace protection is disabled by `sysctl -w kernel.yama.ptrace_scope=0`.
* `-only-eessi`: Install only the EESSI client. No MPI or GPU injection happening.
* `-openmpi5`: Choose OpenMPI version 5 to inject(default).
* `-openmpi4`: Choose OpenMPI version 4 to inject.
* `-aws-ofi-nccl`: Install aws-ofi-nccl plugin for MPI + NVIDIA GPU workloads. By default it will not be installed (Work in Progress).

You can specify these options in the ParallelCluster configuration. In the following example we specify that we want to inject the host openmpi 4 (version 5 is the default) into EESSI, and we want to skip the GPU injection step:

```yaml
HeadNode:
    CustomActions:
        OnNodeConfigured:
            Script: Script: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/env/eessi/assets/postinstall.sh
            Args: ['-openmpi4', '-nogpu']
```

The examples shown are for the HeadNode, but the script must be included as well in the CustomActions of the compute nodes (SlurmQueues in ParallelCluster configuration).

## Access to software

EESSI is set up as a module that can be loaded and unloaded with the `module` command. By default, when login in the HeadNode (e.g. via ssh) it gets automatically loaded and all EESSI software becomes available, see with `module avail`. Furthermore, the default environment module system coming with ParallelCluster images gets overriden by an Lmod provided by EESSI. However, the software modules from ParallelCluster like intelmpi or openmpi are still loadable from EESSI's Lmod, but be aware of not mixing it with EESSI software. Load one or the other.

When submitting jobs with Slurm the environment from the HeadNode is passed to the compute nodes, so if there is a loaded module in the HeadNode it will also be loaded in the compute node for job execution.

A key feature of EESSI is providing optimized binaries for different microachitectures (e.g. intel_skylake, amd_zen2). It is possible to have a ParallelCluster with SlurmQueues that differ in microarchitecture with the HeadNode. Prior to job execution, EESSI will reload all the loaded software if there was a change in microarchitecture from the HeadNode to the SlurmQueue compute node, so that the optimized binaries for the SlurmQueue are used in the job.

To not depend on software modules loaded in the HeadNode, one can include as the first line of the sbatch submission script `module reset`. This will provide an environment where only the EESSI module is loaded (even if in the HeadNode the EESSI module was unloaded), and all EESSI software would be available to load via `module load`.

## References

* For details about the EESSI project, see [EESSI documentation](https://www.eessi.io/docs/)
* For details about CVMFS, see [CVMFS documentation](https://cvmfs.readthedocs.io/en/stable/index.html)
* For details about how to use Lmod, see [Lmod user guide](https://lmod.readthedocs.io/en/latest/010_user.html)
