# Resolvable node names for AWS PCS (cluster_dns)

![Tags: pcs | dns | route53 | lambda | networking | community](https://img.shields.io/badge/tags-pcs%20%7C%20dns%20%7C%20route53%20%7C%20lambda%20%7C%20networking%20%7C%20community-lightgrey)

## Info

AWS PCS gives every node a Slurm node name such as `login-1` or `compute-3`, but that
name does not resolve in the VPC. VPC DNS only knows the EC2-assigned name
(`ip-10-x-x-x.<region>.compute.internal`). Anything that addresses a peer by its Slurm
name then fails, most importantly MPI and `srun`, which exchange short host names when a
job launches across nodes.

This recipe fixes that from the side, without touching the cluster or the VPC's own DNS.
It deploys three things: a per-cluster **Route 53 private hosted zone** associated with
the cluster VPC, a **scoped IAM policy** that lets a node register its own record, and a
**reconcile Lambda** that removes records for nodes that no longer exist. A small **node
lifecycle action (NLA) script** runs on each node at boot; it registers the node's name
and points the node's own resolver at the zone. After that, `compute-2` resolves from any
node in the cluster.

The design is deliberately a **sidecar**: a standalone stack you deploy against a cluster
that already exists, and remove without changing how the cluster is provisioned.

This is a recipe for demonstration and learning, and a **temporary workaround** while a
more sustainable fix is developed. It is not a supported product feature. For the changes
to make before real use, see *Additional considerations*.

## How it works

![Architecture: PCS login and compute nodes run a node lifecycle action at boot that
fetches the script from a public S3 bucket over HTTPS, UPSERTs its own A record into a
Route 53 private hosted zone scoped by an IAM policy on the node role, and sets the zone
as the node's DNS search domain so peers resolve short Slurm names. A reconcile Lambda,
triggered by an EventBridge schedule, calls DescribeInstances and deletes records for
instances that are no longer running.](docs/architecture.png)

The diagram shows the numbered runtime path in dark, the resolution answer as a dashed
line, and the IAM grant in red. Two things happen when a node boots, and one thing happens
on a schedule.

**At boot, each node registers itself.** The NLA script reads the node's Slurm name from
the `PCS_NODE_ID` environment variable the PCS agent provides, reads the node's primary IP
from IMDSv2, and does two things:

```
node boots
  -> PCS agent fetches the NLA script from S3 over HTTPS (checksum-verified)
    -> script UPSERTs  <PCS_NODE_ID>.<zone>  A -> primary IP   (Route 53 private zone)
      -> script sets <zone> as the node's local DNS search domain
```

The UPSERT makes registration idempotent, so `EVERY_BOOT` execution is safe and re-asserts
the record after a reboot. Setting the search domain is what lets a bare short name
(`compute-2`) resolve, not just the fully qualified `compute-2.<zone>`. The script picks
the durable method for the AMI's resolver: a `systemd-resolved` drop-in on the Ubuntu 24
PCS-ready DLAMI and the AL2023 x86 sample AMI, `nmcli ipv4.dns-search` on NetworkManager
systems such as RHEL or Rocky 9, and a plain `/etc/resolv.conf` edit as a last resort.

**On a schedule, the reconcile Lambda cleans up.** A node cannot delete its own record:
PCS lifecycle actions run only at boot, and the instance is terminated out from under any
script. So an EventBridge rule invokes the Lambda every `ReconcileIntervalMinutes`. The
Lambda lists the zone's A records, lists this cluster's running instances (filtered by the
`aws:pcs:cluster-id` tag), and deletes any record whose IP is no longer backed by a live
instance. This is self-healing: it corrects drift no matter how a record was orphaned, and
it resolves the case where an IP is recycled by a different node.

Two facts are worth keeping in mind:

- **`PCS_NODE_ID` is the record name.** It is the Slurm node name (for example `login-1`)
  that peers actually resolve, so the script registers exactly that. The script never reads
  `hostname`, and there is no separate host-name variable to consult.
- **A short TTL bounds staleness.** Records carry `RecordTTL` (default 60 s), so a stale
  answer is cached only briefly in the window before the next reconcile.

The single write grant a node holds is scoped tightly: the IAM policy allows `UPSERT` of
`A` records in this one zone and nothing else (see *Security considerations*).

## Prerequisites

- An existing AWS PCS cluster, and its **VpcId** and **ClusterId** (for example
  `pcs_0123456789`). Find them in the PCS console or with
  `aws pcs get-cluster --cluster-identifier <id>`.
- PCS agent **1.5.0 or later** on the node AMI. Node lifecycle actions require it. The
  current sample AMI and PCS-ready DLAMI ship a newer agent.
- The `aws` CLI and `curl` on the node AMI. Both are present on the sample AMI and the
  PCS-ready DLAMI. A minimal custom AMI may need them added.
- Permission to deploy IAM resources (`CAPABILITY_IAM`) and to update your compute node
  groups.

The private hosted zone is named per cluster (`<ClusterId>.pcs.local` by default), so
several clusters can share one VPC and reuse node-group names without colliding:
`login-1.clusterA.pcs.local` and `login-1.clusterB.pcs.local` stay distinct.

## Deploy (sidecar)

The recipe is decoupled from cluster deployment. You deploy it against a running cluster in
three steps, and remove it the same way (see *Cleaning up*).

### Step 1 - deploy the DNS stack

Use this quick-create link. Change the Region in the URL if you work in a different Region.

[![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/cluster_dns/assets/cluster-dns.yaml)

Or from the CLI:

```bash
aws cloudformation deploy \
  --template-file assets/cluster-dns.yaml \
  --stack-name pcs-cluster-dns \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides VpcId=<vpc-id> ClusterId=<pcs_cluster-id>
```

The operator sets these parameters:

- **VpcId** - the VPC of the target cluster. The hosted zone is associated with it.
- **ClusterId** - the PCS cluster ID. The reconcile Lambda uses it to scope cleanup to
  this cluster's nodes.
- **DomainName** - the zone name. Leave blank to use `<ClusterId>.pcs.local`. Must be
  unique per cluster within the VPC.
- **RecordTTL** - the TTL in seconds for node records. Defaults to `60`.
- **ReconcileIntervalMinutes** - how often the reconcile Lambda runs. Defaults to `5`;
  must be greater than 0.
- **ClusterTagKey** - the EC2 tag that carries the cluster ID. Defaults to
  `aws:pcs:cluster-id`; rarely changed.

When the stack shows `CREATE_COMPLETE`, open its **Outputs** tab. You use:

- **HostedZoneId** and **ZoneName** - pass these to the NLA script in Step 3.
- **NodeDnsManagedPolicyArn** - attach this to your node role in Step 2.
- **RecordTTL** - the TTL to pass to the script.

### Step 2 - attach the managed policy to your node role

The nodes need permission to register their own records. Attach the output
`NodeDnsManagedPolicyArn` to the IAM role your compute node group instances use (for
example the role from the `pcs/getting_started` `pcs-iip-minimal` template):

```bash
aws iam attach-role-policy \
  --role-name <your node role> \
  --policy-arn <NodeDnsManagedPolicyArn output>
```

### Step 3 - add the NLA script to each compute node group

Edit [`assets/example-node-lifecycle-actions.json`](assets/example-node-lifecycle-actions.json),
replacing `REPLACE_WITH_HostedZoneId` and `REPLACE_WITH_ZoneName` with the stack outputs.
The example already pins the script's SHA-256 in `scriptSource.checksum`. Then apply it to
each node group whose nodes need resolvable names:

```bash
aws pcs update-compute-node-group \
  --cluster-identifier <pcs_cluster-id> \
  --compute-node-group-identifier <cng-id> \
  --node-lifecycle-actions file://assets/example-node-lifecycle-actions.json
```

> **Heads up:** updating a node group's lifecycle actions calls `UpdateComputeNodeGroup`,
> which triggers the PCS `DRAIN` strategy. Running jobs finish, then nodes are replaced. It
> is not instant or zero-disruption. Plan the change, and repeat for every node group.

## Verify

After a fresh node in an updated node group comes up, connect to any node in the cluster
(AWS Systems Manager Session Manager works) and confirm resolution:

```bash
getent hosts compute-1              # short Slurm name, via the search domain
getent hosts compute-1.<zone>       # fully qualified
srun -N2 hostname                   # a 2-node step launches and resolves its peers
```

You can also list the zone's records from anywhere with credentials:

```bash
aws route53 list-resource-record-sets --hosted-zone-id <HostedZoneId output>
```

Each running node should have one `A` record, `<PCS_NODE_ID>.<zone>` pointing at its
primary IP. To watch cleanup, terminate a node (or scale a node group down) and confirm the
record disappears within `ReconcileIntervalMinutes`.

## Security considerations

- **Nodes share one write grant to the zone.** The managed policy lets a node UPSERT A
  records in the hosted zone. It is scoped to *UPSERT of A records only*, so a compromised
  node cannot DELETE records or change other record types. But Route 53's IAM model cannot
  restrict a node to only its *own* record name from a role shared by every node, so a
  compromised node could overwrite a peer's A record and redirect traffic within the zone.
  The blast radius is bounded: the zone is private to the VPC, the TTL is short, and the
  reconcile Lambda re-corrects records. All nodes in an HPC cluster already share one trust
  domain, so this is acceptable for a cluster-internal workaround. Do not attach the policy
  to roles outside the cluster.
- **The node runs the NLA script as root from a public bucket.** Integrity rests on TLS and
  the S3 object. The example pins the script's SHA-256 in `scriptSource.checksum`, so the
  PCS agent rejects a tampered download. For anything beyond experimentation, host your own
  copy and pin its checksum.
- **`ec2:DescribeInstances` is account-wide** in the reconcile role because that API does
  not support resource-level permissions. The Lambda filters to this cluster by tag in
  code, and the call is read-only.

## Troubleshooting

**No record appears for a node.** The script is best-effort and exits 0 on any failure, so
read its log on the node at
`/var/log/amazon/pcs/lifecycle/actions/nodeBootstrapped/Register node DNS.log` (root-only;
use `sudo`). Common causes: the `aws` CLI is missing from the AMI, or the managed policy is
not attached to the node role, so the `change-resource-record-sets` call is denied.

**A short name does not resolve, but the FQDN does.** The search domain was not set. Check
the resolver: on `systemd-resolved` AMIs, `resolvectl status` should list the zone under
DNS Domain, and `/etc/systemd/resolved.conf.d/10-pcs-search.conf` should exist. On
NetworkManager AMIs, `nmcli -g ipv4.dns-search connection show <con>` should include the
zone. The script logs which path it took.

**The reconcile Lambda deleted a record for a running node.** A transient
`DescribeInstances` failure can do this. The node re-registers on its next boot, and the
record is idempotent, so the effect is temporary. This is why the script runs `EVERY_BOOT`.

## FAQ

**Why a per-cluster zone instead of one shared zone?** Several clusters can share a VPC and
reuse node-group names. One shared zone would collide on `login-1`. A per-cluster zone keeps
`login-1.clusterA.pcs.local` and `login-1.clusterB.pcs.local` distinct. Associating a
private zone with a VPC needs no DHCP change; the VPC's default resolver answers those
queries automatically.

**Why not a VPC DHCP options set for the search domain?** Changing the DHCP options set is
VPC-wide, affects every instance, allows only one domain suffix, and would collide across
clusters that share a VPC. Enterprise VPC owners rarely allow it. Setting the search domain
per node, locally, avoids touching shared network configuration.

**Why reconcile on a schedule instead of an EventBridge terminate event?** Event delivery
can be missed, and a missed event leaks a record forever. A scheduled reconcile is
self-healing: it corrects the zone no matter how a record was orphaned, and it cleans up
after an abrupt teardown. The same function also purges the zone when the stack is deleted.

**Why is the node's write permission limited to `UPSERT` of `A` records?** That is exactly
what the script needs. Forbidding `DELETE` and other record types means a compromised node
cannot remove a peer's record or tamper with the zone's SOA/NS records. See *Security
considerations* for the residual that IAM cannot close.

**How does a node know its Slurm name at boot?** The PCS agent sets `PCS_NODE_ID` in the
script's environment to the Slurm node name (for example `login-1`). The script registers
that name.

## Cleaning up

Removing the capability is the reverse of deploying, and equally decoupled:

1. Set each node group's lifecycle actions back to empty (`--node-lifecycle-actions '{}'`).
   This is another `DRAIN`-triggering update.
2. Detach the managed policy from the node role.
3. Delete the stack. A delete-time custom resource empties the zone first, so the hosted
   zone is removed cleanly.

```bash
aws cloudformation delete-stack --stack-name pcs-cluster-dns
```

## Additional considerations

This is a recipe for teaching and a stopgap. Before relying on a system like it, consider:

- **A sustainable name-resolution fix.** This registers names from the side. The durable
  answer is for the platform to make Slurm node names resolvable directly.
- **Reverse DNS (PTR).** This recipe provides forward resolution only. Add PTR records if
  your workload needs `IP -> name`.
- **Host your own copy of the script.** For anything beyond experimentation, serve the NLA
  script from a bucket you control and keep the pinned checksum current.
- **Tighten `ec2:CreateTags` on the node role.** The reconcile Lambda trusts the
  `aws:pcs:cluster-id` tag to decide liveness. If nodes can set that tag freely, a rogue
  instance could evade cleanup.
- **Naming from a directory service at scale.** A large, long-lived environment is better
  served by resolving node identity from a single source rather than self-registration.

## Glossary

### node lifecycle action (NLA)
A script AWS PCS runs on a node at a defined boot stage. This recipe uses one at the
`nodeBootstrapped` stage, with `executionPolicy: EVERY_BOOT` (idempotent) and
`onError: CONTINUE` (best-effort). There is no pre-termination stage, which is why cleanup
is external.

### `PCS_NODE_ID`
An environment variable the PCS agent exports to the NLA script. It holds the Slurm node
name (for example `login-1`) - the name peers resolve - so the script uses it as the DNS
record name.

### private hosted zone
A Route 53 zone resolvable only inside the VPCs associated with it. This recipe creates one
per cluster and associates it with the cluster VPC, so records never leave the VPC.

### search domain
The DNS suffix a resolver appends to a bare name. Setting `<zone>` as the node's search
domain is what makes `compute-2` resolve to `compute-2.<zone>` without the caller typing the
suffix.

### reconcile
The scheduled Lambda pass that lists the zone and deletes A records whose IP is not backed
by a running instance tagged for this cluster. It is the cleanup path for terminated nodes
and the zone-emptying step on stack delete.

### UPSERT
The Route 53 change action that creates a record or replaces it if it exists. It makes node
registration idempotent, so re-running on every boot is safe.
