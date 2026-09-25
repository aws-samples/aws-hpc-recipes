# DNS behavior and scaling notes for cluster_dns

Why the search domain is set the way it is, and how resolution behaves at scale. The README
covers the symptoms; this page covers the mechanics behind them.

## Setting the search domain

A node registers `<PCS_NODE_ID>.<zone>` as an A record, which makes the fully qualified name
resolvable on its own. The search domain is what makes the bare Slurm name work, so that
`getent hosts compute-2` succeeds and MPI and `srun` can exchange short host names.

The script picks a method to match the resolver on the AMI, in this order.

### systemd-resolved

This covers the Ubuntu 24 PCS-ready DLAMI and the AL2023 x86 sample AMI. The script writes
`/etc/systemd/resolved.conf.d/10-pcs-search.conf`:

```ini
[Resolve]
DNS=169.254.169.253
Domains=pcs_abc123.pcs.local
```

Two properties matter here, and dropping either one breaks resolution in a way that takes a
while to work out.

**The scope carrying the domain needs a DNS server.** A `Domains=` entry is a *routing* domain
as well as a search domain. Set it without a `DNS=` on the same scope and resolved routes the
zone's queries to a scope with no resolver, and they fail with

```
No appropriate name servers or networks for name found
```

even though the record exists and the VPC resolver would answer it. `169.254.169.253` is the
VPC resolver in any VPC with DNS support enabled, which a private hosted zone requires anyway.

**The setting has to persist in a file.** `resolvectl domain` configures the running resolver
only, and on the PCS-ready DLAMI `systemd-resolved` is stopped and restarted during boot
several minutes *after* the lifecycle action has run. That restart discards runtime state. A
node's resolution would then depend on whether its action happened to run before or after the
restart, which is how a two-node group ended up with one node resolving its peer and the other
not, from identical code.

The drop-in survives a `systemd-resolved` restart, a `systemd-networkd` restart, and leaves
public DNS resolution untouched. It was verified on both supported AMIs, which run resolved in
different `resolv.conf` modes: Ubuntu in stub mode and AL2023 in uplink mode. In uplink mode the
`DNS=` line also inserts `169.254.169.253` ahead of the VPC's `.2` address in `resolv.conf`. Both
answer private hosted zone queries, so that is harmless.

Three approaches were tried here, and the two that failed are the two that look right:

| Approach | Persists | Scope has a resolver | Outcome |
|---|---|---|---|
| Global `Domains=` alone | Yes | No | Nothing in the zone resolved, on either AMI |
| `resolvectl domain` on the link | No | Yes | Correct only if the action ran after the mid-boot restart |
| Drop-in with `Domains=` and `DNS=` | Yes | Yes | Current |

A `systemd-networkd` or netplan drop-in on the link would also satisfy both properties, and is
arguably the more systemd-native answer. It was rejected as too fragile for sample content: the
file name depends on netplan's generated unit name and on the interface name, and the mechanism
differs between the two supported AMIs.

One consequence worth knowing: a global `Domains=` entry sorts ahead of the link's own domain
in the search list, so `/etc/resolv.conf` ends up as

```
search pcs_abc123.pcs.local us-west-2.compute.internal
```

Unqualified lookups therefore try the cluster zone first. A bare EC2-style name such as
`ip-10-3-15-30` gets one `NXDOMAIN` from the zone, which is then cached, before falling through
to `compute.internal`. It still resolves, at the cost of an extra round trip and a negative
cache entry.

### The other two paths are directional

Both AMIs this recipe targets use `systemd-resolved`, so the two paths below never run on a
supported configuration and neither has been exercised on a live node. They're in the script to
show the shape of the problem on other resolvers, not to solve it. If you're on something else,
expect to work out the right method yourself, and note that the script logs a warning saying so.

Registering the record is portable and works anywhere the `aws` CLI does. It's only the search
domain that varies.

**NetworkManager.** Where `systemd-resolved` isn't running but `nmcli` is present, the script
sets `ipv4.dns-search` on the active connection and calls `nmcli device reapply`, which updates
DNS without taking the link down. It sets the absolute value rather than appending, so repeated
boots stay idempotent. NetworkManager persists this in the connection profile, so the mechanism
should be durable in the way the drop-in is, but that has not been confirmed.

**/etc/resolv.conf.** The last resort, when neither of the above is present. This one is
best-effort by construction: any resolver manager rewrites that file on the next network event,
which is the same failure mode that took two attempts to get right on the `systemd-resolved`
path. The script checks for the zone before appending so it doesn't duplicate the entry on
every boot. Treat it as a hint, not a mechanism.

## `.local` and multicast DNS

The default zone name ends in `.local`, which RFC 6762 reserves for multicast DNS. Some
resolvers route `.local` to mDNS instead of to unicast DNS, which would bypass the hosted zone
entirely.

On the Ubuntu 24 PCS-ready DLAMI this doesn't happen. `resolvectl status` reports `-mDNS` and
the effective configuration is `MulticastDNS=no`, so `.local` goes to unicast DNS and a
`resolvectl query` for a node name is answered over DNS on the link.

This has not been checked on other AMIs. If you're unsure, run `resolvectl status` on a node
and look at the protocol flags, or set `DomainName` to a suffix ending in `.internal` instead.

## Negative caching is not bounded by RecordTTL

`RecordTTL` (60 seconds by default) bounds how long a *positive* answer is cached. It has no
effect on negative answers.

When a name is queried before its node has registered, the resolver gets `NXDOMAIN` and caches
that. How long depends on the zone's `SOA` record, not on `RecordTTL`, and works out at about
15 minutes for a Route 53 hosted zone with default settings.

During a large scale-up, a job that queries a peer slightly too early can therefore fail to
resolve it for minutes after that peer is healthy and its record exists. On `systemd-resolved`
nodes, `resolvectl flush-caches` clears it.

This is the behavior most likely to surprise someone using the recipe at scale.

## Registration is one attempt, with no retry

`ChangeResourceRecordSets` is throttled per account, and Route 53 serializes change batches per
hosted zone. The script makes one call. If it fails, the script logs a warning and exits 0, by
design, so that a DNS problem never stops a node from booting.

Nothing retries afterwards. Lifecycle actions run at boot, and the reconcile Lambda only ever
deletes records, so a registration lost to throttling stays lost until that node next boots.

The practical consequences:

- A very large simultaneous scale-up can leave some nodes with no record, and the only signal
  is a warning in a root-only log on each node.
- The throttle is account-wide and Route 53 is a global service, so a big cluster boot can slow
  Route 53 calls elsewhere in the same account.
- The reconcile Lambda competes for the same budget.

If you hit this, stagger large scale-ups or reboot the affected nodes. Adding jitter and a
bounded retry to the script would reduce it, and is a reasonable change to make if you adopt
this pattern.

## What reconcile will and will not touch

The scheduled pass deletes a record only when all of the following hold:

- it is an `A` record,
- its name is exactly one label under the zone, which is the same set of names the node policy
  lets a node write,
- and none of its addresses belongs to an instance currently tagged for this cluster.

Anything else is left alone: names deeper than one label, the apex, and every record type other
than `A`. A record of your own at a deeper name is therefore safe from it.

Two further guards:

- If the instance query returns nothing at all, the pass logs that and deletes nothing. An
  empty result is indistinguishable from a tag filter that matches nothing, so it is treated
  as untrustworthy rather than as "every node is gone".
- Liveness is re-read after the zone is listed, and anything that came up in between is
  dropped from the delete set. This stops a node that registered mid-pass from losing its new
  record.

On stack deletion the same function runs in purge mode, which removes every record except the
apex `SOA` and `NS` that Route 53 requires, so the zone can be deleted.
