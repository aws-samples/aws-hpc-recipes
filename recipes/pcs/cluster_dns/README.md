# Resolvable node names for AWS PCS (cluster_dns)

![Tags: pcs | dns | route53 | lambda | networking | community](https://img.shields.io/badge/tags-pcs%20%7C%20dns%20%7C%20route53%20%7C%20lambda%20%7C%20networking%20%7C%20community-lightgrey)

## Info

AWS PCS gives every node a Slurm node name such as `login-1` or `compute-3`, but that name
does not resolve in the VPC. VPC DNS knows only the EC2-assigned name,
`ip-10-x-x-x.<region>.compute.internal`. Anything that addresses a peer by its Slurm name
fails, and that includes MPI and `srun`, which exchange short host names when a job launches
across nodes.

This recipe fills the gap from the side, without changing the cluster or the VPC's own DNS. It
deploys a per-cluster **Route 53 private hosted zone**, a **scoped IAM policy** that lets a
node register one record for itself, and a **reconcile Lambda** that removes records for nodes
that no longer exist. A **node lifecycle action (NLA) script** runs on each node at boot to
register the node's name and point the node's resolver at the zone. After that, `compute-2`
resolves from any node in the cluster.

The design is a deliberate **sidecar**: a standalone stack you deploy against a cluster that
already exists, and remove without touching how that cluster is provisioned.

This is a recipe for demonstration and learning, and a **temporary workaround** while a more
sustainable fix is developed. It is not a supported product feature. See
*Additional considerations* for what to change before you rely on anything like it.

## Contents

- [How it works](#how-it-works)
- [Prerequisites](#prerequisites)
- [Deploy](#deploy)
- [Verify](#verify)
- [Security considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)
- [Additional considerations](#additional-considerations)
- [Cleaning up](#cleaning-up)
- [Glossary](#glossary)

Two companion pages carry the detail this one summarizes:
[`docs/security.md`](docs/security.md) for the trust model, and
[`docs/dns-behavior.md`](docs/dns-behavior.md) for resolver mechanics and behavior at scale.

## How it works

![Architecture: PCS login and compute nodes run a node lifecycle action at boot that fetches
the script from a public S3 bucket over HTTPS, UPSERTs its own A record into a Route 53 private
hosted zone scoped by an IAM policy on the node role, and sets the zone as the node's DNS
search domain so peers resolve short Slurm names. A reconcile Lambda, triggered by an
EventBridge schedule, calls DescribeInstances and deletes records for instances that are no
longer running.](docs/architecture.png)

The diagram shows the numbered runtime path in dark, the resolution answer as a dashed line,
and the IAM grant in red. Two things happen when a node boots, and one thing happens on a
schedule.

### At boot, each node registers itself

The script reads the node's Slurm name from the `PCS_NODE_ID` environment variable that the PCS
agent provides, reads the node's primary address from IMDSv2, and does two things:

```
node boots
  -> PCS agent fetches the NLA script from S3 over HTTPS (checksum-verified)
    -> script UPSERTs  <PCS_NODE_ID>.<zone>  A -> primary IP   (Route 53 private zone)
      -> script adds <zone> to the node's DNS search domains
```

The `UPSERT` makes registration idempotent, so running the action on every boot is safe and
re-asserts the record if it ever went missing. The search domain is what lets the bare name
`compute-2` resolve rather than only `compute-2.<zone>`.

Which method sets the search domain depends on the AMI's resolver. On `systemd-resolved`
systems the script writes a drop-in naming both the zone and the VPC resolver, which has to
persist in a file rather than in runtime state because `systemd-resolved` restarts later in
boot on some AMIs. [`docs/dns-behavior.md`](docs/dns-behavior.md) explains why both halves
matter, and covers the NetworkManager and `/etc/resolv.conf` fallbacks.

### On a schedule, the reconcile Lambda cleans up

A node can't delete its own record. PCS lifecycle actions run only at boot, and the instance is
terminated out from under any script, so cleanup has to come from outside. An EventBridge rule
invokes the Lambda every `ReconcileIntervalMinutes`. The Lambda lists the zone, lists this
cluster's instances by their `aws:pcs:cluster-id` tag, and deletes any single-value `A` record
whose address no live instance holds. It cleans up however a node went away, including an
abrupt teardown that would lose an event.

Be precise about what reconcile is:

- **It only ever deletes.** It never creates a record or corrects one's value. A record that
  points at the wrong place is left alone if that address belongs to a live instance in the
  cluster.
- **A deleted record returns only at boot.** A node whose record was removed in error stays
  unresolvable until it is rebooted or replaced.
- **It leaves records it did not create alone.** ALIAS records, multi-value records, other
  record types and the zone apex are all skipped, so your own records in this zone are safe.

## Prerequisites

- An existing AWS PCS cluster, and its **VpcId** and **ClusterId** (for example
  `pcs_0123456789`). Find them in the PCS console or with
  `aws pcs get-cluster --cluster-identifier <id>`.
- PCS agent **1.5.0 or later** on the node AMI, which node lifecycle actions require. The
  current sample AMI and PCS-ready DLAMI ship a newer agent.
- The `aws` CLI and `curl` on the node AMI. Both are present on the sample AMI and the
  PCS-ready DLAMI. A minimal custom AMI may need them added.
- Permission to deploy IAM resources (`CAPABILITY_IAM`) and to update your compute node groups.

The zone is named per cluster, `<ClusterId>.pcs.local` by default, so several clusters can
share one VPC and reuse node-group names without colliding. `login-1.clusterA.pcs.local` and
`login-1.clusterB.pcs.local` stay distinct.

## Deploy

Three steps against a running cluster. Removal is the same three in reverse, described under
*Cleaning up*.

### Step 1 - deploy the DNS stack

Use this quick-create link. Change the Region in the URL if you work in a different one.

[![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/cluster_dns/assets/cluster-dns.yaml)

Or from the CLI:

```bash
aws cloudformation deploy \
  --template-file assets/cluster-dns.yaml \
  --stack-name pcs-cluster-dns \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides VpcId=<vpc-id> ClusterId=<pcs_cluster-id>
```

| Parameter | Default | Notes |
|---|---|---|
| `VpcId` | none | The VPC of the target cluster. The hosted zone is associated with it. |
| `ClusterId` | none | The PCS cluster ID. Scopes reconcile to this cluster's nodes. |
| `DomainName` | `<ClusterId>.pcs.local` | Must be unique per cluster in the VPC, **and a name nothing else in your organization resolves**. Lowercase, ending in `.internal` or `.local`. |
| `RecordTTL` | `60` | TTL in seconds for node records. |
| `ReconcileIntervalMinutes` | `5` | Minimum `3`. Below that EventBridge rejects the schedule expression, and runs would overlap the function's timeout. |
| `ClusterTagKey` | `aws:pcs:cluster-id` | The EC2 tag carrying the cluster ID. Leave it alone unless you know why you are changing it. |

`DomainName` deserves a moment's thought. A private hosted zone overrides DNS for its name
across the **whole VPC**, not just the cluster, so reusing a suffix your organization already
resolves breaks those names for every instance in the VPC. See
[`docs/security.md`](docs/security.md).

When the stack shows `CREATE_COMPLETE`, open its **Outputs** tab:

- **HostedZoneId** and **ZoneName** go to the script in Step 3.
- **NodeDnsManagedPolicyArn** is what you attach in Step 2.
- **RecordTTL** is the TTL to pass to the script.

### Step 2 - attach the managed policy to your node role

Nodes need permission to register their own records. Attach the `NodeDnsManagedPolicyArn`
output to the IAM role your compute node group instances use, for example the role from the
`pcs/getting_started` `pcs-iip-minimal` template:

```bash
aws iam attach-role-policy \
  --role-name <your node role> \
  --policy-arn <NodeDnsManagedPolicyArn output>
```

> **Use a role dedicated to this cluster.** The policy grants write access to *this* cluster's
> zone, but a role shared with another cluster hands that cluster's nodes the same access, and
> the per-cluster isolation this design rests on is gone. Give each cluster its own instance
> profile if you run more than one in a VPC.
>
> If you create a fresh role, name both it and its instance profile with an `AWSPCS-` prefix.
> PCS scopes its `PassRole` permission by that prefix, and otherwise rejects the node group
> with "AWS PCS can't access a role associated with the instance profile because the role ARN
> is invalid", which doesn't mention naming.

### Step 3 - add the NLA script to each compute node group

Edit [`assets/example-node-lifecycle-actions.json`](assets/example-node-lifecycle-actions.json),
replacing `REPLACE_WITH_HostedZoneId` and `REPLACE_WITH_ZoneName` with the stack outputs. The
example already pins the script's SHA-256 in `scriptSource.checksum`. Apply it to each node
group whose nodes need resolvable names:

```bash
aws pcs update-compute-node-group \
  --cluster-identifier <pcs_cluster-id> \
  --compute-node-group-identifier <cng-id> \
  --node-lifecycle-actions file://assets/example-node-lifecycle-actions.json
```

> **Heads up:** this calls `UpdateComputeNodeGroup`, which triggers the PCS `DRAIN` strategy.
> Running jobs finish, then nodes are replaced. It is neither instant nor zero-disruption. Plan
> the change, and repeat it for every node group.

## Verify

Once a fresh node in an updated node group comes up, connect to any node in the cluster
(Session Manager works) and check resolution:

```bash
getent hosts compute-1              # short Slurm name, via the search domain
getent hosts compute-1.<zone>       # fully qualified
srun -N2 hostname                   # a 2-node step launches and resolves its peers
```

List the zone's records from anywhere with credentials:

```bash
aws route53 list-resource-record-sets --hosted-zone-id <HostedZoneId output>
```

Every running node should have one `A` record, `<PCS_NODE_ID>.<zone>`, pointing at its primary
address. To watch cleanup, terminate a node or scale a node group down, then confirm the record
disappears within `ReconcileIntervalMinutes`.

## Security considerations

Four things to know before you attach the policy.
[`docs/security.md`](docs/security.md) has the full trust model.

- **A node can overwrite a peer's record.** The policy limits a node to `UPSERT` of a
  single-label `A` record in one zone, which rules out `DELETE`, other record types, the zone
  apex and wildcards. What it can't do is bind a node to its *own* name, because every node
  shares one role. Reconcile does not repair an overwrite, and the TTL does not bound it. The
  zone being private to the VPC is what limits the damage.
- **Every cluster user effectively holds that grant.** An unprivileged job user can read the
  instance role's credentials from IMDS.
- **The zone is VPC-wide.** It overrides DNS for its name for every instance in the VPC, not
  only for cluster nodes, and the search domain means node-role holders can answer unqualified
  lookups for every process on every node.
- **The script runs as root from a public bucket.** The pinned SHA-256 in
  `scriptSource.checksum` is what makes that safe, and the PCS agent rejects a download that
  doesn't match. Host your own copy for anything beyond experimentation.

## Troubleshooting

**No record appears for a node.** The script is best-effort and exits 0 on any failure, so read
its log on the node at
`/var/log/amazon/pcs/lifecycle/actions/nodeBootstrapped/Register node DNS.log` (root-only, so
use `sudo`). The usual causes are a missing `aws` CLI on the AMI, or the managed policy not
attached to the node role.

**Neither the short name nor the FQDN resolves, but `dig @169.254.169.253 <name>` works.** The
record is fine and the node's resolver is the problem. Check that the drop-in exists and names
both a domain and a server:

```bash
cat /etc/systemd/resolved.conf.d/10-pcs-search.conf
grep ^search /etc/resolv.conf
```

You want `Domains=<zone>` **and** `DNS=169.254.169.253`, and the zone present on the `search`
line. A domain with no server on the same scope gives "No appropriate name servers or networks
for name found" even though the record exists. If the file is missing, the action did not run
or did not reach that step, so read its log. If the file is right but resolution still fails,
`sudo systemctl restart systemd-resolved`.
[`docs/dns-behavior.md`](docs/dns-behavior.md) explains both halves.

**A short name fails but the FQDN resolves.** The search domain is missing altogether. On
NetworkManager AMIs, `nmcli -g ipv4.dns-search connection show <con>` should list the zone. The
script logs which path it took.

**Reconcile deleted a record for a running node.** It does not come back on its own: re-register
by hand with `aws route53 change-resource-record-sets`, or reboot the node. Likely causes, in
order: the node registered an address that is on none of its ENIs; the node lacks the
`ClusterTagKey` tag, so reconcile doesn't count it as live; or another node-role holder
overwrote the record. A transient `DescribeInstances` failure is *not* a cause, because the call
raises and the pass stops before deleting anything.

**A short name intermittently fails during a scale-up.** Negative answers are cached for about
15 minutes regardless of `RecordTTL`, so a peer queried slightly too early stays `NXDOMAIN` well
after it is healthy. `resolvectl flush-caches` clears it.

**Nodes in a large scale-up have no records.** `ChangeResourceRecordSets` is throttled per
account and serialized per zone, and the script makes one attempt then gives up until the next
boot. Check the NLA log for a throttling error, then stagger the scale-up or reboot the affected
nodes.

## FAQ

**Why a per-cluster zone instead of one shared zone?** Clusters that share a VPC can reuse
node-group names, and one shared zone would collide on `login-1`. A per-cluster zone keeps
`login-1.clusterA.pcs.local` and `login-1.clusterB.pcs.local` distinct. Associating a private
zone with a VPC needs no DHCP change, because the VPC's resolver answers those queries already.

**Why not a VPC DHCP options set for the search domain?** Changing it is VPC-wide, affects every
instance, allows only one suffix, and collides across clusters sharing a VPC. Enterprise VPC
owners rarely permit it either. Setting the search domain locally on each node avoids touching
shared network configuration.

**Why reconcile on a schedule instead of an EventBridge terminate event?** Event delivery can be
missed, and one missed event leaks a record forever. A scheduled pass cleans up however a record
was orphaned. The same function empties the zone when the stack is deleted.

**Why is the node's write permission limited the way it is?** `UPSERT` of a single-label `A`
record is what the script needs, and each restriction closes something concrete: other record
types would let a node touch the zone's `SOA` and `NS`; the apex would let it block stack
deletion, because Route 53 will not delete a zone that still holds one; and a wildcard would
answer every name in the zone that hadn't registered yet. The `DELETE` restriction buys less
than it looks, which [`docs/security.md`](docs/security.md) covers.

**How does a node know its Slurm name at boot?** The PCS agent sets `PCS_NODE_ID` in the
script's environment to the Slurm node name, for example `login-1`.

## Additional considerations

This is a recipe for teaching and a stopgap. Before depending on a system like it, consider:

- **A sustainable name-resolution fix.** This registers names from the side. The durable answer
  is for the platform to make Slurm node names resolvable directly.
- **Reverse DNS (PTR).** Forward resolution only here. Add PTR records if your workload needs
  address-to-name. Remember that any record type other than `A` is invisible to reconcile.
- **Host your own copy of the script.** Serve it from a bucket you control and keep the pinned
  checksum current.
- **Mediated registration.** To stop a node overwriting a peer's record, have nodes call a small
  Lambda that authenticates the caller's instance identity and writes on their behalf, so nodes
  hold no Route 53 write grant at all.
- **Jitter and retry on registration.** One throttled call currently means no record until the
  next boot.
- **Naming from a directory service at scale.** A large, long-lived environment is better served
  by resolving node identity from one source than by self-registration.

## Cleaning up

Removal is the reverse of deployment, in this order:

1. Set each node group's lifecycle actions back to empty (`--node-lifecycle-actions '{}'`).
   This is another `DRAIN`-triggering update.
2. Detach the managed policy from the node role.
3. Delete the stack. A delete-time custom resource empties the zone so the hosted zone can go.

```bash
aws cloudformation delete-stack --stack-name pcs-cluster-dns
```

Order matters. If nodes are still registering while the stack deletes, the purge races them and
`DeleteHostedZone` fails with `HostedZoneNotEmpty`. If the stack does land in `DELETE_FAILED`,
list what is left, remove it by hand, and delete the stack again:

```bash
aws route53 list-resource-record-sets --hosted-zone-id <HostedZoneId output>
```

Changing `DomainName` on an existing stack **replaces** the hosted zone. The purge runs against
the old zone during that update, but nodes keep their old records and old search domain until
they next boot, so plan it as a redeployment rather than an edit.

## Glossary

### node lifecycle action (NLA)

A script AWS PCS runs on a node at a defined boot stage. This recipe uses one at the
`nodeBootstrapped` stage with `executionPolicy: EVERY_BOOT`, which is safe because every step is
idempotent, and `onError: CONTINUE`, which keeps a DNS failure from stopping the node. There is
no pre-termination stage, which is why cleanup is external.

### `PCS_NODE_ID`

An environment variable the PCS agent exports to the NLA script, holding the Slurm node name
(for example `login-1`). That is the name peers resolve, so the script uses it as the record
name.

### private hosted zone

A Route 53 zone resolvable only inside the VPCs associated with it. This recipe creates one per
cluster and associates it with the cluster VPC, so records never leave the VPC.

### search domain

The DNS suffix a resolver appends to a bare name. Setting `<zone>` as the node's search domain
is what makes `compute-2` resolve to `compute-2.<zone>` without the caller typing the suffix.

### reconcile

The scheduled Lambda pass that lists the zone and deletes single-value `A` records whose address
no running instance tagged for this cluster holds. It is the cleanup path for terminated nodes,
and the zone-emptying step on stack delete. It only deletes.

### UPSERT

The Route 53 change action that creates a record, or replaces it if it exists. It makes node
registration idempotent, so re-running on every boot is safe.
