# Loading a `sacctmgr dump`

Set `sacctmgr_load` to the contents of a file produced by `sacctmgr dump`:

```hcl
module "slurm_accounting" {
  source = "./modules/pcs-slurm-bootstrap"

  cluster_arn   = awscc_pcs_cluster.this.arn
  sacctmgr_load = file("${path.module}/accounting.dump")
}
```

Do not also set `accounts`, `qos`, `users`, or `associations`.

The Lambda parses the canonical dump format and converts it to the same
validated Slurm REST model used by the structured inputs:

```text
QOS - 'normal':Description='Normal work':Priority=100
Cluster - 'source-cluster'
Parent - 'root'
Account - 'research':Description='Research':Organization='Example':FairShare=10
Parent - 'research'
User - 'alice':DefaultAccount='research':DefaultQOS='normal':QOS='normal'
```

The dump's cluster name is not required to match the PCS cluster name. It
identifies the source of the dump; all parsed associations are written to the
PCS cluster selected by `cluster_arn`.

## Behavior

- The operation is equivalent to plain `sacctmgr load`: it upserts records
  present in the file and does not delete omitted records.
- Blank lines and generated comment lines whose first non-whitespace character
  is `#` are ignored.
- `Clean=...` is not supported.
- Records are sent through the individual SlurmDB REST upsert endpoints in
  dependency order: QOS definitions, QOS preemption relationships, accounts,
  users, WCKeys, parent-sorted associations, and coordinators.
- `DefaultAccount` becomes the `is_default` flag on the matching user
  association, which makes it work for newly created users.
- `DefaultWCKey` and `WCKeys` are upserted through the WCKey REST model.
- `AdminLevel` on a user is applied as given; a dump that grants
  `AdminLevel=Administrator` makes that user a Slurm administrator on the
  target cluster.
- `Coordinator` assignments are additive. Existing coordinators not named in
  the dump are retained.
- Cluster `Classification` is accepted but ignored because the PCS cluster
  already exists and is managed by the AWS PCS resource.

The parser accepts the account, user, association, and QOS fields documented in
[accounting-fields.md](accounting-fields.md), using their canonical
`sacctmgr dump` names. It also accepts the CPU, memory, and node aliases
understood by `sacctmgr`, such as `GrpCPUs`, `GrpMemory`, and
`MaxCPUsPerJob`. Slurm 26.05 typed TRES names containing a colon, such as
`gres/gpu:a100`, are preserved.

The automated integration fixture is literal output captured from
`sacctmgr dump` on an AWS PCS Slurm 25.11 login node. It includes the generated
header comments and built-in `root` records. The 26.05 dump grammar remains
compatible and is covered by parser tests, including typed TRES names.

## Deliberate restrictions

- Only one `Cluster` or `Machine` record is accepted.
- QOS records must precede the cluster record, matching canonical dump output.
- `+=` and `-=` are rejected; generated dump files use `=`.
- Association `Comment` is rejected because Slurm REST v0.0.44 and v0.0.45 do
  not reliably update it on an existing association.
- Invalid records, unknown options, duplicate definitions, missing parents,
  unknown account/user/QOS references, and parent or preemption cycles fail
  with a line-specific error before the accounting configuration is written.
