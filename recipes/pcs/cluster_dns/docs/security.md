# Security notes for cluster_dns

This page explains the trust model behind the recipe: what a node can write, what it cannot,
and which risks stay open. The README carries the short version. Read this one before you
attach the managed policy to a role you care about.

This is sample content for demonstration and learning, not a supported product feature.

## What the node grant allows

`NodeDnsManagedPolicy` grants exactly one action, `route53:ChangeResourceRecordSets`, on the
one hosted zone the stack creates. Four IAM conditions narrow it:

| Condition | Effect |
|---|---|
| `ChangeResourceRecordSetsActions` = `UPSERT` | No `DELETE` and no `CREATE` |
| `ChangeResourceRecordSetsRecordTypes` = `A` | No `TXT`, `CNAME`, `SOA`, `NS` or anything else |
| `ChangeResourceRecordSetsNormalizedRecordNames` like `*.<zone>` | One label under the zone |
| The same key, `StringNotLike` `*\052*` and `*.*.<zone>` | No wildcards, no deeper names |

Route 53 normalizes `*` to the octal escape `\052`, which is why the wildcard rule matches
that form.

Each of the three name restrictions closes a specific problem:

- **The zone apex.** Route 53 refuses to delete a hosted zone that still holds records beyond
  its own `SOA` and `NS`. A node able to write the apex could therefore block stack deletion
  and keep the zone alive after teardown.
- **Wildcards.** A record at `*.<zone>` answers every name in the zone that has no exact
  match, so one node could catch lookups for every node that had not registered yet.
- **Deeper names.** One label under the zone is all the script needs, and it keeps the
  namespace flat and predictable.

The policy also uses `Null` conditions to require all three context keys to be present.
`ForAllValues` evaluates to true when its key is absent from the request, so without the
`Null` guards a request that omitted a key would satisfy the restrictions without meeting
them.

The node role holds no `route53:ListResourceRecordSets`. The script never lists records, and
removing the grant takes away an easy way to enumerate every node name and address in the
cluster.

## Reconcile claims the same names the policy grants

The reconcile Lambda decides which records are its business from the record **name**: exactly
one label under the zone apex. That is deliberately the same set of names this policy lets a
node write. The two authorities match, so every record a node can create is a record reconcile
can remove.

Do not be tempted to decide that from the record's *shape* instead, meaning its value count or
whether it carries an `AliasTarget`. Route 53 gives IAM no condition key for shape, so a node
picks the shape freely. A shape-based test therefore lets a node write a record the reconciler
skips on every pass, which then outlives the node that made it and the job that created it. An
earlier version of this recipe skipped multi-value and alias records for exactly that reason,
and a node could use either shape to plant a permanent record at any name it was allowed to
write. Name is the one property both the policy and the reconciler can agree on.

This costs little in practice. The stack creates the zone for one cluster and empties it at
teardown, so single-label node records are essentially all it ever holds. A record you add
yourself at a deeper name, such as `svc.nfs.<zone>`, is outside both authorities: reconcile
ignores it and the node policy refuses to write it.

## The residual that IAM cannot close

**A principal holding the node role can overwrite another node's A record and redirect that
node's traffic inside the zone.**

Route 53's IAM model cannot bind a caller to its *own* record name when every node shares one
role. The name condition limits the *form* of name a node may write, not *which* name.

Three things people expect to bound this, but which don't:

- **Reconcile doesn't repair it.** The Lambda only ever deletes. It has no notion of the
  correct value for a name, so a record pointing at any live instance in the cluster is kept.
- **The TTL doesn't bound it.** `RecordTTL` bounds how long a *stale* answer is cached. An
  overwritten record is wrong, not stale, and it stays wrong until something changes it.
- **Deleting the record doesn't fix it either.** Lifecycle actions run at boot, so a name is
  re-asserted only when the node that owns it next boots.

What does bound it: the zone is private to the VPC, so nothing outside the VPC can read or
reach it, and every node in an HPC cluster already shares one trust domain. For a
cluster-internal workaround that is usually an acceptable trade. Decide that deliberately
rather than by default.

If you need per-node scoping, stop granting nodes a Route 53 write at all. Put a small Lambda
in front: the node calls it, the Lambda authenticates the caller's instance identity, and it
writes the record on the node's behalf. Nodes then hold only `lambda:InvokeFunction` on that
one function.

## Assume every cluster user holds the grant

An unprivileged job user on a node can read the instance role's credentials from the instance
metadata service. There's no step between "a user can run a job" and "a user can call
`ChangeResourceRecordSets` on this zone". When you reason about this recipe, the relevant
principal is any cluster user, not only an attacker who has compromised a node.

## The zone is VPC-wide, not cluster-wide

A Route 53 private hosted zone takes precedence over public DNS for its name and every name
below it, for **every instance in the associated VPC**. The cluster boundary exists in the IAM
policy, not in the resolution path.

So if you set `DomainName` to a suffix your organization already resolves, two things happen
at once. Names under that suffix which the new zone does not contain stop resolving for every
instance in the VPC. And untrusted HPC nodes gain authority over a namespace your other
instances trust.

The parameter only accepts lowercase names ending in `.internal` or `.local`. That is a
guardrail against the obvious mistake, not a guarantee. Pick a name nothing else uses.

## The zone is in every node's search list

Setting the zone as a search domain is what makes `compute-2` resolve instead of only
`compute-2.<zone>`. It also means a principal holding the node role can answer *unqualified*
lookups for every process on every node in the cluster, including processes running as root,
by registering a name the zone does not yet contain. `proxy`, `license` and `mirror` are the
kind of names worth thinking about.

If your nodes only ever use fully qualified names, you don't need the search domain, and
skipping it removes this exposure.

## Use a node role dedicated to one cluster

The policy is scoped to one zone, but a role is not. If two clusters share an instance role
and you attach both policies to it, each cluster's nodes can write into the other's zone, and
the per-cluster isolation the design rests on is gone.

Give each cluster its own instance profile if you run more than one in a VPC. Name a new role
and its instance profile with an `AWSPCS-` prefix: PCS scopes its `PassRole` permission by
that prefix, and rejects the node group otherwise with a message that doesn't mention
naming.

## The node runs the script as root, from a public bucket

PCS fetches the node lifecycle action over HTTPS and runs it as root on every boot. Integrity
rests on TLS plus the SHA-256 in `scriptSource.checksum`, which the PCS agent verifies before
running the script. A tampered download is rejected.

The example config ships with that checksum already pinned. For anything beyond
experimentation, serve the script from a bucket you control and keep the pinned checksum
current. The published path carries the script version, and by convention a new release lands
at a new path rather than changing an existing one, but nothing in the publishing pipeline
enforces that. Hosting your own copy is what actually guarantees the bytes under a config you
have already applied.

## Accepted gaps

These are deliberate, and documented rather than fixed:

- **`ec2:DescribeInstances` is account-wide** in the reconcile role. The API supports no
  resource-level permissions. The call is read-only and the Lambda filters to this cluster by
  tag in code.
- **No dead letter queue, no reserved concurrency, no customer-managed key** on the Lambda.
  A failed reconcile pass is retried by the next scheduled run.
- **DNS queries are plaintext**, confined to the VPC.
- **`--ttl` and `--zone-name` reach the script unvalidated.** Both come from the node group
  configuration an operator writes, not from a cluster user.

## Tag-based liveness

Reconcile decides which nodes are alive from the `ClusterTagKey` tag, which defaults to
`aws:pcs:cluster-id`. EC2 reserves the `aws:` prefix and refuses writes to it from a customer
principal, so that tag cannot be forged, whatever the node role allows.

If you override the parameter with a key outside the reserved namespace, that protection is
gone. Restrict `ec2:CreateTags` on the node role in that case, or a node could tag itself into
another cluster's liveness check.
