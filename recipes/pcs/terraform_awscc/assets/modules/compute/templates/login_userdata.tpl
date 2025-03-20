MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0

packages:
- amazon-efs-utils

runcmd:
# Mount EFS filesystem as /home
- mkdir -p /tmp/home
- rsync -aA /home/ /tmp/home
- echo "${efs_filesystem_id}:/ /home efs tls,_netdev" >> /etc/fstab
- mount -a -t efs defaults
- rsync -aA --ignore-existing /tmp/home/ /home
- rm -rf /tmp/home/
# If provided, mount FSxL filesystem as /shared
- if [ ! -z "${fsx_filesystem_id}" ]; then amazon-linux-extras install -y lustre=latest; mkdir -p /shared; chmod a+rwx /shared; mount -t lustre ${fsx_dns_name}@tcp:/${fsx_mount_name} /shared; chmod 777 /shared; fi
--==MYBOUNDARY==
