# Shared EFS home filesystem

## Info

This recipe demonstrates a launch template that sets up a network-mounted `/home` filesystem on PCS node groups

## Usage

To set up a shared home filesystem:

1. If you do not have one, create an SSH key for accessing your PCS node group(s).
2. If you do not have one, create a security group in the VPC where you are using PCS that allows inbound SSH access.
3. Create an EFS filesystem in the VPC where you are using PCS. You can do this manually or you can use the [efs_simple](../../storage/efs_simple/) recipe.
4. Create a PCS cluster.
5. Deploy [this CloudFormation template](assets/pcs-lt-efs.yaml). Note the ID and version of the launch template for the next step.
6. Create a static (minInstancs=1/maxInstances=1) PCS compute node group that uses the launch template you created. If you want the instances to be publicly accessible, choose a public subnet when you create the node group. 
7. Wait for the compute node group to be created. Note the node group ID.
8. Go to the EC2 console and search for instances tagged with that node group ID. It may take a few minutes for them to launch. When you have identified an instance that is running and has passed a status check, try to connect to it. 

You should be able to SSH into the instance at its public IP address using the SSH key you provided when you created the launch template. Run `df -h` and note that the `/home` is a network mount. Run `ls -alth ~/.ssh/` and note that `authorized_keys` is in place. If you inspect that file you will see it contains the signature of your EC2 SSH key. 

```shell
Last login: Wed May 15 10:58:44 2024 from c-73-167-207-137.hsd1.ma.comcast.net
   ,     #_
   ~\_  ####_        Amazon Linux 2
  ~~  \_#####\
  ~~     \###|       AL2 End of Life is 2025-06-30.
  ~~       \#/ ___
   ~~       V~' '->
    ~~~         /    A newer version of Amazon Linux is available!
      ~~._.   _/
         _/ _/       Amazon Linux 2023, GA and supported until 2028-03-15.
       _/m/'           https://aws.amazon.com/linux/amazon-linux-2023/

[ec2-user@ip-10-3-18-246 ~]$ df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        1.9G     0  1.9G   0% /dev
tmpfs           1.9G     0  1.9G   0% /dev/shm
tmpfs           1.9G  544K  1.9G   1% /run
tmpfs           1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/nvme0n1p1   24G   18G  6.6G  73% /
127.0.0.1:/     8.0E     0  8.0E   0% /home
tmpfs           384M     0  384M   0% /run/user/0
tmpfs           384M     0  384M   0% /run/user/1000

[ec2-user@ip-10-3-18-246 ~]$ ls -alth ~/.ssh/authorized_keys
-rw------- 1 ec2-user ec2-user 100 May 15 10:50 /home/ec2-user/.ssh/authorized_keys
```

## How it works

Simplistically, during the instance boot, we copy the contents of `/home` to a temporary directory. Next, we mount the EFS filesystem at `/home`. Then, we rsync the cached version of `/home` back into place. This preserves files that were created prior to when our bootstrap script began to run. This includes the `authorized_keys` file, which is put in place by `cloud-init` very early in the instance configration workflow. 

```shell
mkdir -p /tmp/home
rsync -a /home/ /tmp/home
echo "EFS-FILESYSTEM-ID:/ /home efs tls,_netdev" >> /etc/fstab
mount -a -t efs defaults
rsync -a --ignore-existing /tmp/home/ /home
rm -rf /tmp/home/
```

There may be ways to make this more robust, but this should demonstrate the general approach you can use. 
