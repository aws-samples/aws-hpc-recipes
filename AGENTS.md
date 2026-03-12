# AWS HPC Recipes

## Quick Reference

This repository contains 100+ infrastructure-as-code recipes for HPC on AWS. Each recipe includes CloudFormation templates, documentation, and assets.

## Repository Map

- `recipes/` — All recipes, organized by namespace (see `docs/ARCHITECTURE.md`)
- `scripts/` — Python utilities for recipe management and validation
- `templates/` — Jinja2 templates for generating recipe scaffolds and docs
- `config/` — Metadata configuration (namespaces, tags, 
colors)
- `docs/` — Deep documentation (start here for details)

## Key Documentation

| Topic | Location |
|-------|----------|
| Recipe structure & namespaces | `docs/ARCHITECTURE.md` |
| CloudFormation rules & patterns | `docs/CLOUDFORMATION.md` |
| Validation & testing | `docs/TESTING.md` |
| Security practices | `docs/SECURITY.md` |
| Code style conventions | `docs/STYLE.md` |
| Development workflow | `docs/develop.md` |
| Linting details | `docs/linting.md` |
| Getting started | `docs/start.md` |

## Essential Commands

```bash
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

## Asset URLs

Templates are mirrored to S3 on merge to main:
- HTTPS: `https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/<namespace>/<recipe>/assets/<file>`
- S3: `s3://aws-hpc-recipes/main/recipes/<namespace>/<recipe>/assets/<file>`
