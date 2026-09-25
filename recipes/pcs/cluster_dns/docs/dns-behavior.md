# DNS behavior and scaling notes for cluster_dns

Why the search domain is set the way it is, and how resolution behaves at scale. The README
covers the symptoms; this page covers the mechanics behind them.

## Setting the search domain

A node registers `<PCS_NODE_ID>.<zone>` as an A record, which makes the fully qualified name
resolvable on its own. The search domain is what makes the bare Slurm name work, so that
`getent hosts compute-2` succeeds and MPI and `srun` can exchange short host names.

The script picks a method to match the resolver on the AMI, in this order.

### systemd-resolved

This covers the Ubuntu 24 PCS-ready DLAMI and the AL2023 x86 sample AMI. The script finds the
interface carrying the default route and adds the zone to that link's search domains:

```bash
resolvectl domain ens5 us-west-2.compute.internal pcs_abc123.pcs.local
```

**The domain has to go on the link, not in the global section of `resolved.conf`.** A
`Domains=` entry is a *routing* domain as well as a search domain. Put the zone in the global
section and resolved routes queries for it to the global scope, which has no DNS server
attached: the VPC resolver belongs to the link. Those queries then fail with

```
No appropriate name servers or networks for name found
```

even though the record exists and the VPC resolver would answer it. You can see the split in
`resolvectl status`, where `Global` carries a `DNS Domain` but no server while the link carries
both.

`resolvectl` writes runtime state rather than a file, so the setting doesn't survive a restart
of `systemd-resolved`. The action runs with `executionPolicy: EVERY_BOOT`, which re-applies it
on each boot.

The script also deletes `/etc/systemd/resolved.conf.d/10-pcs-search.conf` if it finds one. A
global drop-in at that path is the broken form described above, and leaving it in place would
keep a stale routing domain alongside the correct link setting.

### NetworkManager

On RHEL, Rocky 9 and similar systems without `systemd-resolved`, the script sets
`ipv4.dns-search` on the active connection and calls `nmcli device reapply`, which updates DNS
without taking the link down. It sets the absolute value rather than appending, so repeated
boots stay idempotent.

### /etc/resolv.conf

The last resort, used when neither of the above is present. A resolver manager rewrites that
file on the next network event, so treat this path as best effort. The script checks for the
zone before appending, so it doesn't add a duplicate entry on every boot.

Neither of the last two paths has been exercised on a live node. The AMIs this recipe
recommends both take the `systemd-resolved` path.

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
- it carries exactly one value,
- it is not the zone apex,
- and its address belongs to no instance currently tagged for this cluster.

Anything else is left alone: ALIAS records, which carry no address values, multi-value
records, and every record type other than `A`. Records you add to this zone yourself are safe
from it.

Two further guards:

- If the instance query returns nothing at all, the pass logs that and deletes nothing. An
  empty result is indistinguishable from a tag filter that matches nothing, so it is treated
  as untrustworthy rather than as "every node is gone".
- Liveness is re-read after the zone is listed, and anything that came up in between is
  dropped from the delete set. This stops a node that registered mid-pass from losing its new
  record.

On stack deletion the same function runs in purge mode, which removes every record except the
apex `SOA` and `NS` that Route 53 requires, so the zone can be deleted.
