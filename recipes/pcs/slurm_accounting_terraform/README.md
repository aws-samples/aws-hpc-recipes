# Slurm accounting bootstrap for AWS PCS (Terraform)

## Legal Disclaimer

This is sample code, not for production use. It is provided as-is with no
warranty. Use at your own risk.

This Terraform module configures the Slurm accounting database of an
[AWS Parallel Computing Service (AWS PCS)](https://docs.aws.amazon.com/pcs/)
cluster as part of a `terraform apply`. It deploys a small VPC-connected Lambda
function and invokes it synchronously after the cluster is `ACTIVE`. The Lambda
mints a short-lived Slurm JWT from the cluster's PCS-managed signing key and
upserts accounts, QOS records, users, WCKeys, coordinators, and associations
through the cluster's `slurmrestd` endpoint.

Why this exists: PCS queues can reference QOS records (for example
`DenyQos=preempt` or `AllowQos=high`), but nothing in the PCS API creates those
records. Without this module a cluster is not usable until someone logs in to a
node and runs `sacctmgr`. With it, the accounting configuration is declared next
to the cluster and the queue, and Terraform orders them correctly.

Two input forms are supported:

- Structured Terraform values (`accounts`, `qos`, `users`, `associations`)
  using Slurm REST field names.
- The literal contents of a file produced by `sacctmgr dump` (`sacctmgr_load`).

## What the module does and does not manage

The module is **upsert-only**. It is a bootstrap step, not a full Terraform
representation of the Slurm accounting database.

- Adding or changing a record upserts it.
- Removing a record from Terraform leaves the existing Slurm record alone.
- `terraform destroy` removes the Lambda and its supporting AWS resources and
  leaves every Slurm accounting record in place.
- Terraform cannot detect manual changes made with `sacctmgr`. Change
  `force_run_token` to deliberately replay the desired upserts.
- Coordinator lists are additive: configured coordinators are merged with
  existing coordinators.

If you need delete or drift-detection semantics, this module is not the right
tool; manage the database with `sacctmgr` or a Slurm-native tool instead.

## Supported Slurm versions

| AWS PCS Slurm version | Slurm REST data parser |
| --- | --- |
| 25.11 | v0.0.44 |
| 26.05 | v0.0.45 |

The writable accounting fields are identical between these two REST contracts.
Automatic API discovery prefers these tested contracts when the cluster
advertises them. If a future cluster offers only a newer version that still has
all required REST routes, the bootstrap proceeds with that version and logs a
warning instead of rejecting the cluster. Older PCS Slurm versions are not
supported.

## Requirements

### Tooling

- Terraform 1.5 or newer. OpenTofu should work but has not been tested.
- Provider `hashicorp/aws` 5.80 or newer and `hashicorp/awscc` 1.98 or newer,
  both configured for the cluster's Region.
- Python is **not** required locally. The Lambda uses only the Python standard
  library and the `boto3` bundled in the Lambda runtime.

### PCS cluster

- Slurm 25.11 or 26.05.
- Slurm accounting in `STANDARD` mode (`slurm_configuration.accounting.mode`).
- Slurm REST API in `STANDARD` mode (`slurm_configuration.slurm_rest.mode`).

The module checks all three before invoking the Lambda and fails with a clear
message if any is missing (at plan time for an existing cluster, at apply time
for a cluster created in the same run).

### Networking

The Lambda runs inside your VPC. By default it uses the subnets and security
groups of the PCS cluster endpoint; both can be overridden with
`lambda_subnet_ids` and `lambda_security_group_ids`.

It needs two kinds of connectivity:

1. **TCP 6820 to the cluster's `SLURMRESTD` endpoint.** When the Lambda reuses
   the cluster endpoint security group, that group must allow self-referenced
   ingress on 6820. When the Lambda uses its own security group, the cluster
   endpoint security group must allow 6820 from it. The module does not change
   customer-managed security group rules.

2. **Reachability of two AWS APIs from the private subnet.** The Lambda calls
   `pcs:GetCluster` (to read the endpoint and signing-key reference) and
   `secretsmanager:GetSecretValue` (to read the JWT signing key). A private
   subnet with no route to these APIs makes the invocation time out with no
   useful error. Provide one of:

   - A route to the internet through a NAT gateway, or
   - Interface VPC endpoints for `com.amazonaws.<region>.pcs` and
     `com.amazonaws.<region>.secretsmanager`, with private DNS enabled and a
     security group that allows TCP 443 from the Lambda security group.

   Interface endpoints are billed per hour and per GB, so the examples in this
   repository do not create them. If you need them, this is the shape:

   ```hcl
   resource "aws_vpc_endpoint" "pcs" {
     vpc_id              = var.vpc_id
     service_name        = "com.amazonaws.${var.region}.pcs"
     vpc_endpoint_type   = "Interface"
     subnet_ids          = [var.subnet_id]
     security_group_ids  = [aws_security_group.pcs.id]
     private_dns_enabled = true
   }

   resource "aws_vpc_endpoint" "secretsmanager" {
     vpc_id              = var.vpc_id
     service_name        = "com.amazonaws.${var.region}.secretsmanager"
     vpc_endpoint_type   = "Interface"
     subnet_ids          = [var.subnet_id]
     security_group_ids  = [aws_security_group.pcs.id]
     private_dns_enabled = true
   }
   ```

   The Lambda also writes to CloudWatch Logs, but that traffic goes through the
   Lambda service, not your VPC, so no `logs` endpoint is needed.

### IAM for the Terraform principal

Beyond the permissions needed to create the Lambda, its IAM role, and its log
group, the identity running `terraform apply` needs `lambda:InvokeFunction` on
the module's function, and read access to the cluster through the `awscc`
provider (AWS Cloud Control API over `pcs:GetCluster`), which it already has if
it created the cluster.

## Usage

The complete, runnable configurations live in
[`assets/examples/`](assets/examples/):

- [`assets/examples/complete`](assets/examples/complete/): creates a cluster,
  bootstraps accounting from structured values, then creates a compute node
  group and a queue whose `DenyQos` setting references a QOS the module created.
- [`assets/examples/sacctmgr-dump`](assets/examples/sacctmgr-dump/): creates a
  cluster and loads a `sacctmgr dump` file.

To use the module from a checkout of this repository, point `source` at the
`assets/` directory. To use it from a `terraform init` without a checkout, use
the `github.com/...//...` form shown below.

The essential shape:

```hcl
resource "awscc_pcs_cluster" "this" {
  name = "research-cluster"
  size = "SMALL"

  scheduler = {
    type    = "SLURM"
    version = "26.05"
  }

  networking = {
    subnet_ids         = [var.subnet_id]
    security_group_ids = [aws_security_group.pcs.id]
  }

  slurm_configuration = {
    accounting = { mode = "STANDARD" }
    slurm_rest = { mode = "STANDARD" }
  }
}

module "slurm_accounting" {
  source = "github.com/aws-samples/aws-hpc-recipes//recipes/pcs/slurm_accounting_terraform/assets"

  cluster_arn = awscc_pcs_cluster.this.arn

  qos = {
    normal  = { description = "Normal work", priority = 100 }
    preempt = { description = "QOS denied from the batch queue" }
  }

  accounts = {
    research = { description = "Research workloads", organization = "Example" }
  }

  users = {
    alice = {
      administrator_level = ["None"]
      default             = { account = "research" }
    }
  }

  associations = [
    {
      account    = "research"
      user       = "alice"
      default    = { qos = "normal" }
      qos        = ["normal"]
      shares_raw = 10
    }
  ]
}

resource "awscc_pcs_queue" "batch" {
  # ...
  slurm_configuration = {
    slurm_custom_settings = [
      { parameter_name = "DenyQos", parameter_value = "preempt" }
    ]
  }

  depends_on = [module.slurm_accounting]
}
```

Passing the cluster ARN to the module creates an implicit dependency on the
cluster. Downstream PCS resources that rely on the accounting records (queues
that reference a QOS, compute node groups you want gated on a complete
bootstrap) should declare `depends_on = [module.slurm_accounting]`; the module
invokes the Lambda synchronously and fails the apply if any upsert fails, so
those resources are not created until the records exist.

### Structured inputs

`accounts`, `qos`, and `users` are maps keyed by record name; the values are
Slurm REST fields other than `name`. `associations` is a list of Slurm REST
association objects; the module adds `cluster` when it is omitted and rejects
any other cluster name. The field names, value shapes, and corresponding
`sacctmgr` names are listed in [docs/accounting-fields.md](docs/accounting-fields.md).

Rules the Lambda enforces before writing anything:

- Each configured account gets a cluster-level account association
  (`parent_account` defaults to `root`). To customize it, include an
  association with the account name and an omitted or empty `user`.
- Account associations are sorted parent-first automatically. An account with
  more than one cluster-level association, a self-parent, a parent cycle, or a
  non-`root` parent not declared in `accounts` is rejected.
- Association `account`, `user`, and `qos` references must be declared in this
  module's inputs. Records that already exist in Slurm do not satisfy them.
- QOS `preempt` references must be declared in `qos`; preemption cycles are
  rejected.

### Loading a `sacctmgr dump`

```hcl
module "slurm_accounting" {
  source = "github.com/aws-samples/aws-hpc-recipes//recipes/pcs/slurm_accounting_terraform/assets"

  cluster_arn   = awscc_pcs_cluster.this.arn
  sacctmgr_load = file("${path.module}/accounting.dump")
}
```

`sacctmgr_load` is mutually exclusive with the structured inputs. The dump's
cluster name identifies the source cluster; all associations are retargeted to
the cluster selected by `cluster_arn`. Behavior matches plain `sacctmgr load`
(not `sacctmgr load Clean=...`): omitted records are not deleted. A dump is
applied in full, so any `AdminLevel=` settings and `Coordinator=` grants it
contains are applied to the target cluster. See
[docs/sacctmgr-load.md](docs/sacctmgr-load.md) for the accepted syntax.

## How a run works

1. Terraform reads the cluster through `awscc_pcs_cluster` and checks the
   status and Slurm configuration preconditions.
2. Terraform packages `assets/lambda/` and creates (or updates) the function, role,
   policy, and log group.
3. `aws_lambda_invocation` calls the function synchronously with the desired
   configuration as the payload.
4. The Lambda re-reads the cluster, fetches the signing key, mints a root JWT
   valid for `jwt_ttl_seconds`, discovers a compatible REST API version,
   pings `slurmctld` and `slurmdbd`, then issues the upserts in dependency
   order: QOS, QOS preemption, accounts, users, WCKeys, associations,
   coordinators.
5. The Lambda returns a summary (exposed as `module.<name>.bootstrap_result`)
   or raises, which fails the apply.

### Re-run and failure behavior

The invocation runs again whenever the desired configuration, Lambda code,
cluster ARN, effective networking, request settings, API preference, or
`force_run_token` changes. Re-applying an unchanged configuration does not
invoke the Lambda.

If the invocation fails (Lambda exception, HTTP failure, Slurm `errors` in a
response, or Lambda timeout) the apply fails and the invocation is **not**
recorded in state. Fix the cause and run `terraform apply` again; the bootstrap
is retried automatically. Each phase is an idempotent upsert, so a partial run
is safe to repeat. The Lambda log group (`/aws/lambda/<function_name>`) holds
structured JSON log entries for the run summary, warnings, and errors.

## Security notes

- The Lambda mints a Slurm JWT for user `root`. Anyone with
  `lambda:InvokeFunction` on the function can therefore perform any Slurm
  accounting operation on the cluster. The function is private to your account
  and has no trigger other than Terraform; treat invoke permission on it as
  cluster administrator access.
- The Lambda role is scoped to `pcs:GetCluster` on this cluster,
  `secretsmanager:GetSecretValue` on this cluster's signing-key secret, its own
  log group, and the standard VPC network-interface actions.
- The signing key and the minted token are never logged. The structured JSON
  log contains the negotiated REST API version, upsert counts, any Slurm
  warnings, and the error message of a failed run.
- The desired configuration (account, user, and QOS names and limits) is stored
  in Terraform state as the invocation input. It contains no credentials.
- Per the
  [AWS PCS documentation](https://docs.aws.amazon.com/pcs/latest/userguide/slurm-rest-api.html),
  the `slurmrestd` endpoint is reachable only on a private IP inside the
  cluster VPC and connections to it are not TLS-encrypted at the application
  layer. The module speaks HTTP to that private address; traffic never leaves
  your VPC.
- Default JWT lifetime is 300 seconds (configurable, 60-900).

## Inputs

| Name | Description | Default |
| --- | --- | --- |
| `cluster_arn` | ARN of the AWS PCS cluster. Required. | |
| `accounts` | Accounts to upsert, keyed by name. | `{}` |
| `qos` | QOS records to upsert, keyed by name. | `{}` |
| `users` | Users to upsert, keyed by name. | `{}` |
| `associations` | Association objects to upsert. | `[]` |
| `sacctmgr_load` | Contents of a `sacctmgr dump` file. Mutually exclusive with the four inputs above. | `null` |
| `lambda_subnet_ids` | Subnets for the Lambda. `null` uses the cluster endpoint subnets. | `null` |
| `lambda_security_group_ids` | Security groups for the Lambda. `null` uses the cluster endpoint security groups. | `null` |
| `function_name` | Lambda function name. `null` derives one from the cluster ID. | `null` |
| `slurm_rest_api_version` | `auto`, or a specific `v0.0.N`. | `"auto"` |
| `jwt_ttl_seconds` | Lifetime of the generated root JWT (60-900). | `300` |
| `request_timeout_seconds` | Per-request timeout to `slurmrestd` (1-60). | `15` |
| `request_retries` | Retries for transient HTTP/network failures (0-10). | `3` |
| `lambda_timeout_seconds` | Lambda timeout (30-900). | `120` |
| `log_retention_days` | CloudWatch Logs retention. | `14` |
| `force_run_token` | Change to force a re-run with no other changes. | `""` |
| `tags` | Tags for supported resources. | `{}` |

## Outputs

| Name | Description |
| --- | --- |
| `bootstrap_result` | Summary returned by the Lambda: `status`, `cluster`, `apiVersion`, `configurationSha256`, `upserted` counts. |
| `completion_id` | Opaque hex value that changes each time the bootstrap runs. Safe to embed in scripts; use it to order downstream resources after the bootstrap. |
| `configuration_sha256` | SHA-256 of the desired configuration payload. |
| `lambda_function_name`, `lambda_function_arn` | The deployed function. |
| `lambda_networking` | Effective subnet and security group IDs. |
| `pcs_cluster` | ARN, ID, and name of the target cluster. |

## Known limitations

- Upsert-only; see above.
- Association `comment` is not supported because Slurm REST v0.0.44/v0.0.45 do
  not reliably update it on existing associations.
- `MaxTRESRunMins` is accepted and stored, but the v0.0.44 and v0.0.45 REST
  schemas label enforcement of that association limit as not implemented.
- Coordinator updates are read-modify-write and not atomic with respect to
  concurrent `sacctmgr` changes.
- `sacctmgr dump` files using `Clean=`, `+=`, or `-=` are rejected.

## Recipe layout

```
slurm_accounting_terraform/
├── README.md                                          This file
├── metadata.yml                                       Recipe index metadata
├── assets/
│   ├── main.tf, variables.tf, outputs.tf, versions.tf   The module
│   ├── lambda/                                        Lambda source (stdlib only)
│   └── examples/
│       ├── complete/                                  Cluster + structured bootstrap + queue
│       └── sacctmgr-dump/                             Cluster + dump-file bootstrap
├── docs/                                              Field reference and dump syntax
└── tests/                                             Python unit tests and fixtures
```

## Testing

Unit tests need only Python 3.12+ and run from the recipe directory:

```shell
make test
```

or directly with `python3 -m unittest discover -s tests -v`. They cover
configuration normalization, `sacctmgr dump` parsing, REST API version
negotiation, JWT minting, and the handler's dependency ordering against a fake
`slurmrestd`.

The module has been verified against AWS PCS clusters running Slurm 25.11 and
26.05 by checking the resulting `sacctmgr` and `scontrol` output on a login
node.

## License

This recipe is distributed under the same license as the rest of this
repository; see the repository's `LICENSE` file.
