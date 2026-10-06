# Load a `sacctmgr dump` file

Creates a `SMALL` AWS PCS cluster in an existing VPC subnet and loads
[`accounting.dump`](accounting.dump) into its Slurm accounting database. Use
this pattern to carry an existing cluster's accounts, users, QOS records, and
associations over to PCS.

## Produce the dump

On the source cluster:

```shell
sacctmgr dump <cluster-name> file=accounting.dump
```

Copy the file into this directory (or point `dump_file` at it). The cluster
name inside the file is informational; every association is written to the PCS
cluster this example creates. The sample file ships two QOS records, a
two-level account tree, and two users.

Behavior matches plain `sacctmgr load`: records present in the file are
upserted and records absent from it are left alone. `Clean=`, `+=`, and `-=`
are rejected. The full accepted grammar is in
[`docs/sacctmgr-load.md`](../../../docs/sacctmgr-load.md).

## Prerequisites

Same as [`examples/complete`](../complete/README.md): an existing VPC and
subnet with a path to the PCS and Secrets Manager APIs, and credentials that
can create PCS clusters, IAM roles, Lambda functions, and security groups.

## Run

```shell
cp terraform.tfvars.example terraform.tfvars   # edit region, vpc_id, subnet_id
terraform init
terraform apply
```

On success `bootstrap_result` reports the upserted record counts. To verify,
run `sacctmgr dump <pcs-cluster-name>` on a cluster node and compare with the
input file; the customer-defined records dump identically (Slurm may add
inherited values to the built-in `root` records).

## Reload after editing the file

Changing `accounting.dump` changes the module's input, so the next
`terraform apply` loads the file again. Records removed from the file are not
deleted.

Run `terraform destroy` when you are done; the cluster is billed while it
exists.
