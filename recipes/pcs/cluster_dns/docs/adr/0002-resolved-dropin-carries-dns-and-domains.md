# The resolved drop-in carries both Domains= and DNS=

On `systemd-resolved` systems the node script writes
`/etc/systemd/resolved.conf.d/10-pcs-search.conf` with two settings, not one:

```ini
[Resolve]
DNS=169.254.169.253
Domains=pcs_abc123.pcs.local
```

The `DNS=` line looks redundant, because the node already has a working resolver. It is not. A
`Domains=` entry in `systemd-resolved` is a *routing* domain as well as a search domain, so the
scope carrying it must also have a resolver. Set `Domains=` alone in the global section and
resolved routes the zone's queries to a scope with no DNS server: they fail with "No appropriate
name servers or networks for name found" even though the record exists and the VPC resolver would
answer it. `169.254.169.253` is the VPC resolver in any VPC with DNS support enabled, which a
private hosted zone requires anyway.

The file also has to be a *file*. `resolvectl domain` configures only the running resolver, and on
the PCS-ready DLAMI `systemd-resolved` is stopped and restarted during boot several minutes after
the lifecycle action has already run. That restart discards runtime state.

## Considered options

- **Global `Domains=` with no `DNS=`.** The first attempt. Persists, but routes the zone to a
  scope with no resolver, so nothing in the zone resolved on either supported AMI. The recipe's
  headline behaviour never worked.
- **`resolvectl domain` on the default-route link.** The second attempt. Correct scope, but
  runtime-only. A two-instance node group showed one node resolving its peer and the other not,
  from identical code, because one action ran before the mid-boot resolved restart and the other
  after. Correct by luck is not correct.
- **A `systemd-networkd` or netplan drop-in on the link.** Persistent and link-scoped, which is
  arguably the most systemd-native answer. Rejected as too fragile for sample content: the file
  name depends on netplan's generated unit name and the interface name, and the mechanism differs
  between the two supported AMIs.
- **A global drop-in carrying both settings.** Chosen. One file, no dependence on interface or
  link-manager naming, works on both supported AMIs. Verified to survive a `systemd-resolved`
  restart, a `systemd-networkd` restart, and to leave public DNS untouched.

## Consequences

A global `Domains=` entry sorts ahead of the link's own domain in the search list, so
`/etc/resolv.conf` becomes `search <zone> <region>.compute.internal`. Unqualified lookups try the
cluster zone first, and a bare EC2-style name takes one cached `NXDOMAIN` from the zone before
falling through. It still resolves, at the cost of a round trip.

That ordering also widens the search-domain exposure described in `docs/security.md`: a name a
node registers in the zone is consulted before the VPC's own domain.

The two supported AMIs run resolved in different `resolv.conf` modes, Ubuntu in stub and AL2023 in
uplink. The drop-in was verified in both. In uplink mode the `DNS=` line also inserts
`169.254.169.253` ahead of the VPC's `.2` address in `resolv.conf`; both answer private hosted
zone queries, so this is benign.
