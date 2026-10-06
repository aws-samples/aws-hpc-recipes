# Structured accounting fields

The structured inputs use the writable field names common to Slurm REST
v0.0.44 and v0.0.45, as exposed by AWS PCS Slurm 25.11 and 26.05. Unknown or
misplaced fields fail the Lambda invocation before any REST write.

Terraform map keys provide account, QOS, and user names:

```hcl
accounts = {
  research = {
    description  = "Research workloads"
    organization = "Example"
  }
}
```

## Where each setting belongs

| Desired setting | Terraform input |
| --- | --- |
| Account description, organization, or coordinators | `accounts.<name>` |
| User admin level, default account, WCKeys, or coordinator accounts | `users.<name>` |
| Account hierarchy or account-level limits and QOS policy | An `associations` entry with `account` set and `user` omitted |
| User membership, partition, default QOS, allowed QOS, shares, priority, or limits | An `associations` entry with both `account` and `user` set |
| QOS policy, preemption, flags, priority, usage factors, or limits | `qos.<name>` |
| An existing canonical `sacctmgr dump` file | `sacctmgr_load`; do not combine it with the structured inputs |

Account, QOS, and user definitions are maps because their names are unique.
Associations are a list because one user can have associations with multiple
accounts or partitions.

Most limit fields accept a non-negative integer. Slurm no-value limit fields
also accept `null` to request no change or `{ infinite = true }` to make the
limit unlimited. `limits.grace_time` and `shares_raw` require a non-negative
integer and do not accept either special form. Wall-clock limits are expressed
in minutes; `preempt.exempt_time` and `limits.grace_time` are seconds.

TRES limits are lists of objects:

```hcl
limits = {
  max = {
    tres = {
      per = {
        job = [
          { type = "cpu", count = 32 },
          { type = "gres", name = "gpu", count = 4 },
        ]
      }
    }
  }
}
```

`type` is required. `name` is used for named TRES such as `gres/gpu`, and
`count` is a non-negative integer in Slurm's base unit (memory counts are MiB).
A TRES list must not be empty.

For an association, a supplied TRES list is the complete desired value of that
one TRES field. For a QOS, Slurm applies the supplied TRES entries as
modifications. Omit a TRES field to leave it unchanged. The module does not
expose clearing an entire TRES field because Slurm REST ignores an empty list.

## Accounts

| Terraform field | `sacctmgr` equivalent | Notes |
| --- | --- | --- |
| `description` | `Description` | Defaults to the account name when omitted. |
| `organization` | `Organization` | Defaults to the parent account, or the account name for a root child. |
| `coordinators` | User `Coordinator` | List of configured user names. Additive; existing coordinators are retained. |

Association limits written on an `Account` line in a dump belong in the
account's cluster-level `associations` entry, not in the `accounts` object.

## Users

| Terraform field | `sacctmgr` equivalent | Notes |
| --- | --- | --- |
| `administrator_level` | `AdminLevel` | One-element list: `["Not Set"]`, `["None"]`, `["Operator"]`, or `["Administrator"]`. |
| `default.account` | `DefaultAccount` | Must match one configured non-partition user association. The module writes `is_default` on that association. |
| `default.wckey` | `DefaultWCKey` | Also upserts the named WCKey. |
| `wckeys` | `WCKeys` | List of WCKey names; the module supplies the user and target cluster. |
| `coordinators` | `Coordinator` | List of configured account names for which this user is a coordinator. Additive. |

User limits, `DefaultQOS`, `QosLevel`, `FairShare`, comments, and partitions are
association properties and belong in `associations`.

## Associations

Identifiers:

| Terraform field | `sacctmgr` equivalent | Notes |
| --- | --- | --- |
| `account` | Current `Parent` for a user; account name for an account | Required. Must be declared in `accounts`, except the built-in `root` account. |
| `user` | User name | Omit or set to `null` for a cluster-level account association. |
| `partition` | `Partition` | Only valid for user associations. |
| `parent_account` | Current `Parent` | Only valid for account associations; defaults to `root`. |
| `cluster` | `Cluster` | Optional. If present, it must equal the target PCS cluster name. |
| `is_default` | `DefaultAccount` | Boolean; marks this as the user's default account association. |

Limits and policy:

| Terraform field | `sacctmgr` equivalent |
| --- | --- |
| `default.qos` | `DefaultQOS` |
| `qos` | `QOS` / `QosLevel` |
| `shares_raw` | `FairShare` / `Shares` |
| `priority` | `Priority` |
| `max.jobs.per.count` | `GrpJobs` |
| `max.jobs.per.accruing` | `GrpJobsAccrue` |
| `max.jobs.per.submitted` | `GrpSubmitJobs` |
| `max.tres.total` | `GrpTRES` |
| `max.tres.group.minutes` | `GrpTRESMins` |
| `max.tres.group.active` | `GrpTRESRunMins` |
| `max.per.account.wall_clock` | `GrpWall` |
| `max.jobs.active` | `MaxJobs` |
| `max.jobs.accruing` | `MaxJobsAccrue` |
| `max.jobs.total` | `MaxSubmitJobs` |
| `max.tres.minutes.per.job` | `MaxTRESMinsPerJob` |
| `max.tres.minutes.total` | `MaxTRESRunMins` |
| `max.tres.per.job` | `MaxTRES` / `MaxTRESPerJob` |
| `max.tres.per.node` | `MaxTRESPerNode` |
| `max.jobs.per.wall_clock` | `MaxWallDurationPerJob` |
| `min.priority_threshold` | `MinPrioThresh` |

`comment` is intentionally unsupported. Slurm REST v0.0.44 and v0.0.45 accept
it when creating an association but do not apply it when updating an existing
association, so exposing it would not provide reliable upsert behavior.

Slurm accepts and stores `max.tres.minutes.total` (`MaxTRESRunMins`), but its
v0.0.44 and v0.0.45 schemas label enforcement of that association limit as not
implemented.

## QOS

General fields:

| Terraform field | `sacctmgr` equivalent | Notes |
| --- | --- | --- |
| `description` | `Description` | Arbitrary description. |
| `priority` | `Priority` | QOS priority factor. |
| `usage_factor` | `UsageFactor` | Floating-point usage multiplier. |
| `usage_threshold` | `UsageThreshold` | Floating-point minimum fair-share threshold. |
| `flags` | `Flags` | List of REST enum names shown below. |
| `preempt.list` | `Preempt` | List of configured QOS names this QOS can preempt. |
| `preempt.mode` | `PreemptMode` | List containing `DISABLED`, `SUSPEND`, `REQUEUE`, `CANCEL`, or `GANG`. |
| `preempt.exempt_time` | `PreemptExemptTime` | Seconds. |

Supported persistent `flags` values are `DENY_LIMIT`,
`ENFORCE_USAGE_THRESHOLD`, `NO_DECAY`, `NO_RESERVE`,
`OVERRIDE_PARTITION_QOS`, `PARTITION_MAXIMUM_NODE`,
`PARTITION_MINIMUM_NODE`, `PARTITION_QOS`, `PARTITION_TIME_LIMIT`,
`RELATIVE`, `REQUIRED_RESERVATION`, and `USAGE_FACTOR_SAFE`. The REST control
values `ADD`, `REMOVE`, and `NOT_SET` are also accepted; they respectively add
flags, remove flags, or leave the current flags unchanged.

Limit fields:

| Terraform field | `sacctmgr` equivalent |
| --- | --- |
| `limits.grace_time` | `GraceTime` |
| `limits.factor` | `LimitFactor` |
| `limits.max.active_jobs.accruing` | `GrpJobsAccrue` |
| `limits.max.active_jobs.count` | `GrpJobs` |
| `limits.max.jobs.count` | `GrpSubmitJobs` |
| `limits.max.tres.total` | `GrpTRES` |
| `limits.max.tres.minutes.total` | `GrpTRESMins` |
| `limits.max.tres.minutes.per.qos` | `GrpTRESRunMins` |
| `limits.max.wall_clock.per.qos` | `GrpWall` |
| `limits.max.jobs.active_jobs.per.account` | `MaxJobsPerAccount` / `MaxJobsPA` |
| `limits.max.jobs.active_jobs.per.user` | `MaxJobsPerUser` / `MaxJobsPU` |
| `limits.max.accruing.per.account` | `MaxJobsAccruePerAccount` / `MaxJobsAccruePA` |
| `limits.max.accruing.per.user` | `MaxJobsAccruePerUser` / `MaxJobsAccruePU` |
| `limits.max.jobs.per.account` | `MaxSubmitJobsPerAccount` / `MaxSubmitJobsPA` |
| `limits.max.jobs.per.user` | `MaxSubmitJobsPerUser` / `MaxSubmitJobsPU` |
| `limits.max.tres.minutes.per.job` | `MaxTRESMinsPerJob` |
| `limits.max.tres.minutes.per.account` | `MaxTRESRunMinsPerAccount` |
| `limits.max.tres.minutes.per.user` | `MaxTRESRunMinsPerUser` |
| `limits.max.tres.per.account` | `MaxTRESPerAccount` |
| `limits.max.tres.per.job` | `MaxTRES` / `MaxTRESPerJob` |
| `limits.max.tres.per.node` | `MaxTRESPerNode` |
| `limits.max.tres.per.user` | `MaxTRESPerUser` |
| `limits.max.wall_clock.per.job` | `MaxWallDurationPerJob` |
| `limits.min.priority_threshold` | `MinPrioThresh` |
| `limits.min.tres.per.job` | `MinTRESPerJob` |

Response-only fields such as numeric IDs, usage records, lineage, accounting
history, deletion flags, and embedded account/user associations are rejected.
