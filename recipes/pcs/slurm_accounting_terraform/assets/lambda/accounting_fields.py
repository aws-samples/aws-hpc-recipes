# Writable SlurmDB fields common to REST data parser v0.0.44 (Slurm 25.11)
# and v0.0.45 (Slurm 26.05).

ACCOUNT_FIELDS = frozenset(
    {
        "coordinators",
        "description",
        "organization",
    }
)

USER_FIELDS = frozenset(
    {
        "administrator_level",
        "coordinators",
        "default.account",
        "default.wckey",
        "wckeys",
    }
)

ASSOCIATION_FIELDS = frozenset(
    {
        "account",
        "cluster",
        "default.qos",
        "is_default",
        "max.jobs.accruing",
        "max.jobs.active",
        "max.jobs.per.accruing",
        "max.jobs.per.count",
        "max.jobs.per.submitted",
        "max.jobs.per.wall_clock",
        "max.jobs.total",
        "max.per.account.wall_clock",
        "max.tres.group.active",
        "max.tres.group.minutes",
        "max.tres.minutes.per.job",
        "max.tres.minutes.total",
        "max.tres.per.job",
        "max.tres.per.node",
        "max.tres.total",
        "min.priority_threshold",
        "parent_account",
        "partition",
        "priority",
        "qos",
        "shares_raw",
        "user",
    }
)

QOS_FIELDS = frozenset(
    {
        "description",
        "flags",
        "limits.factor",
        "limits.grace_time",
        "limits.max.accruing.per.account",
        "limits.max.accruing.per.user",
        "limits.max.active_jobs.accruing",
        "limits.max.active_jobs.count",
        "limits.max.jobs.active_jobs.per.account",
        "limits.max.jobs.active_jobs.per.user",
        "limits.max.jobs.count",
        "limits.max.jobs.per.account",
        "limits.max.jobs.per.user",
        "limits.max.tres.minutes.per.account",
        "limits.max.tres.minutes.per.job",
        "limits.max.tres.minutes.per.qos",
        "limits.max.tres.minutes.per.user",
        "limits.max.tres.minutes.total",
        "limits.max.tres.per.account",
        "limits.max.tres.per.job",
        "limits.max.tres.per.node",
        "limits.max.tres.per.user",
        "limits.max.tres.total",
        "limits.max.wall_clock.per.job",
        "limits.max.wall_clock.per.qos",
        "limits.min.priority_threshold",
        "limits.min.tres.per.job",
        "preempt.exempt_time",
        "preempt.list",
        "preempt.mode",
        "priority",
        "usage_factor",
        "usage_threshold",
    }
)

SUPPORTED_FIELDS = {
    "accounts": ACCOUNT_FIELDS,
    "associations": ASSOCIATION_FIELDS,
    "qos": QOS_FIELDS,
    "users": USER_FIELDS,
}

ASSOCIATION_TRES_FIELDS = frozenset(
    field
    for field in ASSOCIATION_FIELDS
    if ".tres." in field or field.endswith(".tres")
)

ASSOCIATION_LIMIT_FIELDS = frozenset(
    {
        "max.jobs.accruing",
        "max.jobs.active",
        "max.jobs.per.accruing",
        "max.jobs.per.count",
        "max.jobs.per.submitted",
        "max.jobs.per.wall_clock",
        "max.jobs.total",
        "max.per.account.wall_clock",
        "min.priority_threshold",
        "priority",
    }
)

QOS_TRES_FIELDS = frozenset(
    field
    for field in QOS_FIELDS
    if ".tres." in field or field.endswith(".tres")
)

QOS_LIMIT_FIELDS = frozenset(
    {
        "limits.max.accruing.per.account",
        "limits.max.accruing.per.user",
        "limits.max.active_jobs.accruing",
        "limits.max.active_jobs.count",
        "limits.max.jobs.active_jobs.per.account",
        "limits.max.jobs.active_jobs.per.user",
        "limits.max.jobs.count",
        "limits.max.jobs.per.account",
        "limits.max.jobs.per.user",
        "limits.max.wall_clock.per.job",
        "limits.max.wall_clock.per.qos",
        "limits.min.priority_threshold",
        "preempt.exempt_time",
        "priority",
    }
)

QOS_FLOAT_LIMIT_FIELDS = frozenset(
    {
        "limits.factor",
        "usage_factor",
        "usage_threshold",
    }
)

ADMINISTRATOR_LEVELS = frozenset(
    {
        "Administrator",
        "None",
        "Not Set",
        "Operator",
    }
)

QOS_FLAGS = frozenset(
    {
        "ADD",
        "DENY_LIMIT",
        "ENFORCE_USAGE_THRESHOLD",
        "NO_DECAY",
        "NO_RESERVE",
        "NOT_SET",
        "OVERRIDE_PARTITION_QOS",
        "PARTITION_MAXIMUM_NODE",
        "PARTITION_MINIMUM_NODE",
        "PARTITION_QOS",
        "PARTITION_TIME_LIMIT",
        "RELATIVE",
        "REMOVE",
        "REQUIRED_RESERVATION",
        "USAGE_FACTOR_SAFE",
    }
)

PREEMPT_MODES = frozenset(
    {
        "CANCEL",
        "DISABLED",
        "GANG",
        "REQUEUE",
        "SUSPEND",
    }
)
