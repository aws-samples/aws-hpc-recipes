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
`aws:pcs:cluster-id` tag), and deletes any single-value A record whose IP is no longer held
by a live instance. It cleans up after terminated nodes however they went away, including
an abrupt teardown that would lose an event.

Be precise about what reconcile is and is not:

- **It only ever deletes.** It never re-creates or corrects a record's value. If a record
  points somewhere wrong but that address belongs to a live instance in the cluster,
  reconcile leaves it alone — it has no notion of the *right* value for a name.
- **A deleted record comes back only at boot.** PCS lifecycle actions run at boot, so a
  node whose record was removed in error stays unresolvable until it is rebooted or
  replaced. The effect is not self-correcting within a running instance's lifetime.
- **It leaves records it did not create alone.** Anything that is not a single-value A
  record — an ALIAS, a multi-value record, the zone apex — is skipped, so adding your own
  records to this zone is safe.

Three more facts worth keeping in mind:

- **`PCS_NODE_ID` is the record name.** It is the Slurm node name (for example `login-1`)
  that peers actually resolve, so the script registers exactly that. The script never reads
  `hostname`, and there is no separate host-name variable to consult.
- **A short TTL bounds positive staleness only.** Records carry `RecordTTL` (default 60 s).
  It does **not** bound negative caching: a name queried before its node registers yields
  `NXDOMAIN`, cached for the zone's negative TTL (about 900 s from Route 53's default SOA)
  regardless of `RecordTTL`. During a large scale-up a job can therefore fail to resolve a
  peer for several minutes after that peer is healthy.
- **Registration is one attempt with no retry.** `ChangeResourceRecordSets` is throttled
  per account and serialized per hosted zone. A node whose call is throttled logs a warning
  and gives up until its next boot, so a very large simultaneous scale-up can leave some
  nodes silently unregistered.

The single write grant a node holds is scoped to `UPSERT` of `A` records, at exactly one
label under this one zone, and nothing else (see *Security considerations*).

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
  unique per cluster within the VPC, **and must be a name nothing else in your organization
  resolves** - the zone overrides DNS for it across the whole VPC. Lowercase, ending in
  `.internal` or `.local`.
- **RecordTTL** - the TTL in seconds for node records. Defaults to `60`.
- **ReconcileIntervalMinutes** - how often the reconcile Lambda runs. Defaults to `5`,
  minimum `3`. Below that, EventBridge rejects the schedule expression and invocations
  would overlap the function's timeout.
- **ClusterTagKey** - the EC2 tag that carries the cluster ID. Defaults to
  `aws:pcs:cluster-id`. Leave it alone unless you know why you are changing it: the default
  is in a reserved namespace that cannot be forged, and a value matching no instances makes
  reconcile skip its pass.

When the stack shows `CREATE_COMPLETE`, open its **Outputs** tab. You use:

- **HostedZoneId** and **ZoneName** - pass these to the NLA script in Step 3.
- **NodeDnsManagedPolicyArn** - attach this to your node role in Step 2.
- **RecordTTL** - the TTL to pass to the script.

### Step 2 - attach the managed policy to your node role

The nodes need permission to register their own records. Attach the output
`NodeDnsManagedPolicyArn` to the IAM role your compute node group instances use (for
example the role from the `pcs/getting_started` `pcs-iip-minimal` template).

> **Use a role dedicated to this cluster.** The policy grants write access to *this*
> cluster's zone. If the role is shared with another cluster, that cluster's nodes get the
> same access, and the per-cluster isolation this design relies on is gone. Give each
> cluster its own instance profile if you run more than one in a VPC.

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

- **Nodes share one write grant to the zone.** The managed policy lets a node UPSERT a
  single-label `A` record under the zone. It denies `DELETE`, other record types, the zone
  apex, multi-label names, and wildcards. Route 53's IAM model still cannot restrict a node
  to its *own* record name from a role shared by every node, so **a compromised node can
  overwrite a peer's A record and redirect that peer's traffic within the zone.** Reconcile
  does not repair this: if the record points at any live instance in the cluster, reconcile
  keeps it. The short TTL does not bound it either — the record is wrong, not stale. What
  does bound it: the zone is private to the VPC, and the affected name is re-asserted the
  next time the victim node boots. All nodes in an HPC cluster already share one trust
  domain, so this is acceptable for a cluster-internal workaround. If you need per-node
  scoping, the durable answer is to mediate registration — nodes call a small Lambda that
  authenticates the caller's instance identity and writes the record on their behalf, and
  hold no Route 53 write grant at all.
- **The grant is reachable by any user on a node, not only by "a compromised node."** An
  unprivileged job user can read the instance role's credentials from IMDS. Treat every
  cluster user as holding this permission.
- **Use a node role dedicated to one cluster.** The policy is per-zone, but a role shared
  across clusters (reusing `pcs-iip-minimal`, say) gives every cluster's nodes write access
  to every zone whose policy is attached, which defeats the per-cluster isolation the design
  rests on. Do not attach the policy to roles outside the cluster.
- **The zone overrides DNS for the whole VPC, not just the cluster.** A private hosted zone
  takes precedence over public DNS for its name and every name under it, for *every*
  instance in the associated VPC. Choose a `DomainName` nothing else in your organization
  resolves — otherwise you both break resolution for real names under that suffix and hand
  untrusted HPC nodes authority over a namespace your other instances trust. The parameter
  is constrained to lowercase names ending in `.internal` or `.local` as a guardrail, not a
  guarantee.
- **The zone is in every node's DNS search list.** That is what makes short names resolve,
  and it also means any principal holding the node role can answer *unqualified* lookups
  (`proxy`, `license`, a peer's bare name) for every process on every node, including root,
  by registering a name the zone does not yet contain.
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

**The reconcile Lambda deleted a record for a running node.** The record does **not** come
back on its own — lifecycle actions run at boot, so the node stays unresolvable until it is
rebooted or replaced. Re-register by hand with `aws route53 change-resource-record-sets`, or
reboot the node. Likely causes, in order: the node registered an address that is not on any
of its ENIs; the node is not tagged with `ClusterTagKey`, so reconcile does not see it as
live; or the record was overwritten by another principal holding the node role. A transient
`DescribeInstances` failure is *not* a cause — the call raises and the pass aborts before
deleting anything, and an empty instance list is treated as untrustworthy and skipped.

**A short name intermittently fails to resolve during a scale-up.** Negative answers are
cached for the zone's negative TTL (about 900 s), which `RecordTTL` does not affect. A peer
queried before it registered stays `NXDOMAIN` in the resolver cache for minutes after it is
healthy. On `systemd-resolved` nodes, `resolvectl flush-caches` clears it.

**Nodes in a large scale-up have no records.** `ChangeResourceRecordSets` is throttled per
account and serialized per hosted zone, and the script makes one attempt then gives up until
the next boot. Check the node's NLA log for a throttling error. Stagger large scale-ups, or
reboot the affected nodes.

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
can be missed, and a missed event leaks a record forever. A scheduled pass cleans up
however a record was orphaned, including after an abrupt teardown. The same function also
empties the zone when the stack is deleted.

**Why is the node's write permission limited this way?** `UPSERT` of a single-label `A`
record is exactly what the script needs. The restrictions rule out concrete problems:
forbidding other record types keeps the zone's SOA/NS intact; forbidding the apex matters
because Route 53 refuses to delete a hosted zone that still holds an apex record, so a node
could otherwise block stack deletion; and forbidding wildcards matters because `*.<zone>`
would answer every unregistered name in the zone. Note the limit on `DELETE` buys less than
it appears — see *Security considerations* for the peer-overwrite residual that IAM cannot
close.

**How does a node know its Slurm name at boot?** The PCS agent sets `PCS_NODE_ID` in the
script's environment to the Slurm node name (for example `login-1`). The script registers
that name.

## Cleaning up

Removing the capability is the reverse of deploying, and equally decoupled:

1. Set each node group's lifecycle actions back to empty (`--node-lifecycle-actions '{}'`).
   This is another `DRAIN`-triggering update.
2. Detach the managed policy from the node role.
3. Delete the stack. A delete-time custom resource empties the zone first so the hosted
   zone can be removed.

```bash
aws cloudformation delete-stack --stack-name pcs-cluster-dns
```

Do the steps in that order. If nodes are still registering while the stack is deleting, the
purge races them and `DeleteHostedZone` fails with `HostedZoneNotEmpty`. If the stack does
land in `DELETE_FAILED`, list what is left and remove it by hand, then delete the stack
again:

```bash
aws route53 list-resource-record-sets --hosted-zone-id <HostedZoneId output>
```

Changing `DomainName` on an existing stack **replaces** the hosted zone. The purge runs
against the old zone during that update, but the nodes keep their old records and their old
search domain until they next boot, so plan it like a redeployment rather than an edit.

## Additional considerations

This is a recipe for teaching and a stopgap. Before relying on a system like it, consider:

- **A sustainable name-resolution fix.** This registers names from the side. The durable
  answer is for the platform to make Slurm node names resolvable directly.
- **Reverse DNS (PTR).** This recipe provides forward resolution only. Add PTR records if
  your workload needs `IP -> name`.
- **Host your own copy of the script.** For anything beyond experimentation, serve the NLA
  script from a bucket you control and keep the pinned checksum current.
- **Leave `ClusterTagKey` at its default.** The reconcile Lambda trusts that tag to decide
  liveness. The default `aws:pcs:cluster-id` is in the reserved `aws:` namespace, which EC2
  will not let a customer principal set, so it cannot be forged — and `ec2:CreateTags` on the
  node role does not change that. If you override the parameter with a non-reserved key, that
  protection is gone and you should restrict `ec2:CreateTags` on the node role.
- **A `.local` zone suffix and multicast DNS.** The default suffix is `<ClusterId>.pcs.local`.
  RFC 6762 reserves `.local` for multicast DNS, and `systemd-resolved` special-cases it. If
  mDNS is active on your AMI, a `.local` name could in principle be answered over mDNS by any
  host on the link rather than from the zone. This recipe has not been verified either way on
  the recommended AMIs; if it matters to you, check `resolvectl status` on a node and set
  `DomainName` to a `.internal` suffix instead.
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
The scheduled Lambda pass that lists the zone and deletes single-value A records whose IP is
not held by a running instance tagged for this cluster. It is the cleanup path for terminated
nodes and the zone-emptying step on stack delete. It only ever deletes: it never creates a
record or corrects one's value.

### UPSERT
The Route 53 change action that creates a record or replaces it if it exists. It makes node
registration idempotent, so re-running on every boot is safe.
