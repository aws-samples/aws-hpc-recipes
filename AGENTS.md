# AWS HPC Recipes

Guidance for coding agents (and people) working in this repository. `CLAUDE.md` is a
symlink to this file, so both point at the same content.

## What this repository is

A collection of 100+ infrastructure-as-code recipes for building HPC systems on AWS.
The recipes focus on [AWS Parallel Computing Service (PCS)](https://aws.amazon.com/pcs/),
the managed Slurm service, and also cover AWS ParallelCluster, Research and Engineering
Studio (RES), AWS Batch, and supporting services (networking, storage, directory, and
databases). Most recipes are AWS CloudFormation templates; some use Terraform, CDK, or
shell.

## Read this before you change anything

These are the invariants an agent gets wrong most often here. Get them right and the
rest is ordinary editing.

- **Partition safety is enforced by CI.** Never hardcode `arn:aws:` or `amazonaws.com`
  in a template. Use `!Sub "arn:${AWS::Partition}:..."` for ARNs and
  `!Sub "https://console.${AWS::URLSuffix}/..."` for console URLs so templates work in
  AWS GovCloud and China Regions. Genuinely partition-specific lines are exempted with a
  `# partition-exception: <reason>` comment. See `docs/CLOUDFORMATION.md`.
- **`recipes/README.md` is generated. Do not hand-edit it.** It is rendered from each
  recipe's `metadata.yml` and the namespace list in `config/metadata/values.yml`. To
  change it, edit those inputs and run `make readme`. Namespace order on the page follows
  the order of `config/metadata/values.yml`.
- **Recipes have a fixed layout.** Each recipe lives at `recipes/<namespace>/<recipe>/`
  and must contain `README.md`, `metadata.yml`, `Makefile`, `assets/`, `docs/`, and
  `tests/`. Scaffold new recipes with `python -m scripts.new_recipe` rather than building
  the directory by hand. See `docs/ARCHITECTURE.md`.
- **Validate before you call it done.** Run `make validate`. It runs four checks:
  recipe structure, `metadata.yml` schema, partition safety, and `cfn-lint`. ShellCheck
  runs too, with a two-tier policy: scripts under `recipes/pcs-scripts/` must pass cleanly
  (blocking); scripts elsewhere get advisory warnings. See `docs/TESTING.md`.

## Repository map

- `recipes/` — All recipes, organized by namespace. Each namespace has a short landing
  `README.md`; the full catalog is the generated `recipes/README.md`.
- `scripts/` — Python utilities for recipe management, rendering, and validation.
- `templates/` — Jinja2 templates for recipe scaffolds and the generated catalog.
- `config/` — Metadata configuration (namespaces, tags, colors).
- `docs/` — Deep documentation. Start here for detail.

## Deep documentation

| Topic | Location |
|-------|----------|
| Recipe structure, namespaces, metadata schema | `docs/ARCHITECTURE.md` |
| CloudFormation rules and partition safety | `docs/CLOUDFORMATION.md` |
| Validation and testing | `docs/TESTING.md` |
| Security practices | `docs/SECURITY.md` |
| Code style conventions | `docs/STYLE.md` |
| Development workflow | `docs/develop.md` |
| Linting details | `docs/linting.md` |
| Getting started | `docs/start.md` |

## Essential commands

```bash
# Set up the Python environment
python -m venv .env && source .env/bin/activate
pip install -r requirements.txt

# Create a new recipe (interactive)
python -m scripts.new_recipe

# Regenerate recipes/README.md from metadata
make readme

# Run all validation (structure, metadata, partitions, cfn-lint)
make validate

# Build and test all recipes
make build
make test

# Deploy to S3 (personal testing)
HPCDK_TAG=mybranch HPCDK_S3_BUCKET=mybucket HPCDK_PROFILE=myprofile make deploy
```

## Contributing

Pull request titles use the format `[namespace/recipe] Description`. See `CONTRIBUTING.md`
for the review bar: recipes are checked for general security issues but are not tested or
maintained by the maintainers.

## Asset URLs

Recipe assets under `assets/` are mirrored to S3 on merge to the main branch:

- HTTPS: `https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/<namespace>/<recipe>/assets/<file>`
- S3: `s3://aws-hpc-recipes/main/recipes/<namespace>/<recipe>/assets/<file>`
