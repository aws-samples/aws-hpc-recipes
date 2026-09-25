# Reconcile decides ownership by record name, not record shape

The reconcile Lambda has to decide which records in the zone are its business. It decides from
the record **name**: exactly one label under the zone apex, which is deliberately the same set of
names `NodeDnsManagedPolicy` lets a node write. The two authorities are identical, so every
record a node can create is a record reconcile can remove.

The obvious alternative, and the one this recipe tried first, is to decide from the record's
*shape*: act only on a single-value `A` record, on the reasoning that this is the only shape the
node script produces, so anything else must belong to an operator. Do not do this. Route 53
offers IAM no condition key for a record's value count or for the presence of an `AliasTarget`,
so a node chooses shape freely. A shape-based test therefore lets a node write a record that
reconcile skips on every pass, which outlives the node and the job that created it. With the zone
ahead of `<region>.compute.internal` in every node's search list, that is a permanent answer for
an unqualified name across the cluster.

## Considered options

- **Shape (single-value `A` only).** Rejected. Not expressible in IAM, so it hands a node a way
  to make a record permanently invisible to cleanup. This was the state of the code for one
  revision and a security review found it.
- **Type only (`A`, not apex).** Rejected earlier still, for the opposite failure: it deleted
  operator-created ALIAS records on every pass, because an ALIAS carries no addresses and so
  looked unbacked.
- **Name (one label under the apex).** Chosen. Name is the one property both the policy and the
  reconciler can constrain, so the code and the IAM conditions cannot drift apart.
- **Mediated registration.** A node calls a Lambda that authenticates its instance identity and
  writes on its behalf, so nodes hold no Route 53 write at all. This is the durable answer and it
  removes the question entirely, but it is a larger design than this sidecar recipe is meant to
  be. Recorded in `docs/security.md` as the path to take if per-node scoping is required.

## Consequences

Records an operator keeps in this zone must sit deeper than one label, for example
`svc.nfs.<zone>`. In practice this costs nothing: the stack creates the zone for one cluster and
empties it at teardown, so single-label node records are essentially all it ever holds.

The general rule worth carrying forward: **decide ownership from a property the authorization
system can also enforce.** This selector was wrong twice, in opposite directions, and both
versions passed every static check and looked correct in review.
