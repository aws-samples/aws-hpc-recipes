# Spack on PCS with shared filesystem

## Info

Get Spack running on PCS using a shared filesystem. 

## Usage

1. Set up a cluster.
2. Add a static compute node group with a shared fileystem (see [getting_started](../getting_started/) for a general how-to on this with EFS).
3. Log into an instance managed by the static node group.
4. Download `install.sh` to the instance: 
5. Check out the installer usage with `bash install.sh -h`, then run the script with options you choose.
```shell
# For example, run it in the background
bash install.sh --directory /shared spec spec 

# or, add -fg to run in the foreground

bash install.sh --directory /shared -fg spec spec 
```
6. Add a compute node group with the same shared filesystem.

Spack should be available, and accessible from 