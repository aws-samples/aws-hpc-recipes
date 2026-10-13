# Architecture

## Recipe Structure

Every recipe lives at `recipes/<namespace>/<recipe_name>/` and must contain:

```
recipes/<namespace>/<recipe_name>/
├── README.md           # User-facing documentation (required)
├── metadata.yml        # Recipe metadata for indexing (required)
├── Makefile            # Build and test targets (required)
├── assets/             # CloudFormation templates and downloadable files (required)
├── docs/               # Additional documentation (required, can be empty)
└── tests/              # Validation scripts (required, can be empty)
```

## Namespaces

Recipes are organized into namespaces defined in `config/metadata/values.yml`:

| Namespace | Description |
|-----------|-------------|
| `pcs` | AWS Parallel Computing Service (default) |
| `pcs-scripts` | PCS node lifecycle action scripts (community) |
| `net` | Networking |
| `storage` | Storage |
| `db` | Database management |
| `dir` | Directory services |
| `iam` | Identity and Access Management |
| `security` | Security configuration |
| `env` | User environment |
| `ide` | IDEs and GUIs |
| `scheduler` | HPC scheduler |
| `aws` | General AWS |
| `training` | Teaching and training recipes |
| `batch` | AWS Batch |
| `pcluster` | AWS ParallelCluster |
| `res` | Research and Engineering Studio on AWS |

## Metadata Schema

Each `metadata.yml` must include these fields:

```yaml
name: recipe_name          # Required. Must match directory name.
version: "1.0.0"           # Required. Semantic versioning.
description: "..."         # Required. Short summary.
readme: README.md          # Required. Path to README.
authors:                   # Required. List of authors.
  - Author Name
tags:                      # Required. List of tags for indexing.
  - service-tag
  - maturity-tag           # One of: core, beta, community
type: cloudformation       # Required. One of: cloudformation, cdk, shell, terraform, other
```

Valid tags and their display colors are defined in `config/metadata/values.yml`.

## Asset Hosting

Recipe assets under `assets/` are synced to S3 on merge to main. They are accessible at:
- `https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/<namespace>/<recipe>/assets/<file>`
- `s3://aws-hpc-recipes/main/recipes/<namespace>/<recipe>/assets/<file>`

## Dependency Direction

Recipes should be composable. Complex recipes can reference simpler ones via CloudFormation nested stacks or imports. The general dependency direction is:

```
net/ → storage/ → db/dir/ → pcs/batch/pcluster/res/ → training/
```

Networking and storage recipes are foundational. Service-specific recipes build on top of them.
