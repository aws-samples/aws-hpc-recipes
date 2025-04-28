
## Purpose

The aim of this script is to setup the bastion host so that when a user logs in to it, they will see a list of their currently running virtual desktops. This then allows them to ssh to the virtual desktop they want to access.

## Instructions

1. Attach the policy `AmazonEC2ReadOnlyAccess` to the IAM role of the Bastian host. Alternatively you can create a new role that only allows to the [EC2 DescribeInstances API](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_DescribeInstances.html).

2. Copy the find_user_instances.sh file to the Bastian host, and run the below commands

```bash
chmod +x ./find_user_instances.sh
sudo cp ./find_user_instances.sh /etc/profile.d/find_user_instances.sh
```

3. Logout and login again - you should see the ip addresses of your instances now show up at login.

4. You should be able to login to any of the listed nodes with ssh.