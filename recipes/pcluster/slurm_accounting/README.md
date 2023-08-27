# slurm_accounting

## Info

Create an instance of AWS ParallelCluster with Slurm accounting enabled, using Amazon RDS as the DBMS.

## Usage

## Cost Estimate

## Key Learnings

* The `AdminPasswordSecretString` parameter is an excellent example of using a regular expression to validate inputs.
* Make sure to add the security group for the database cluster to the head node (see `Resources.PclusterCluster.Properties.ClusterConfiguration.HeadNode.Networking.AdditionalSecurityGroups`)
* The database cluster in this recipe launches in private subnets shared with the compute nodes. This is  not mandatory as long as its IP is reachable from the head node. 
