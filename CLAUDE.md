# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AWS HPC Recipes: 100+ infrastructure-as-code recipes for High Performance Computing on AWS. Recipes deploy HPC infrastructure using CloudFormation templates for AWS Parallel Computing Service (PCS), ParallelCluster, Research and Engineering Studio (RES), and AWS Batch.

## Deep Documentation

Detailed rules and conventions live in `docs/`:
- `docs/ARCHITECTURE.md` — Recipe structure, namespaces, metadata schema
- `docs/CLOUDFORMATION.md` — Partition safety, parameter/output patterns
- `docs/TESTING.md` — Validation pipeline, local testing
- `docs/SECURITY.md` — Credential handling, IAM, scanning tools
- `docs/STYLE.md` — YAML, Python, Markdown conventions

## Development Commands

```bash
# Setup Python environment
python -m venv .env && source .env/bin/activate
pip install -r requirements.txt

# Create new recipe (interactive)
python -m scripts.new_recipe

# Regenerate recipes/README.md from metadata
make readme

# Run all validation (structure, metadata, partitions, cfn-lint)
make validate

# Build/test all recipes
make build
make test

# Deploy to S3 (personal testing)
HPCDK_TAG=mybranch HPCDK_S3_BUCKET=mybucket HPCDK_PROFILE=myprofile make deploy
```

## CloudFormation Critical Rule

All templates must support AWS GovCloud and China partitions:
- Use `!Sub "arn:${AWS::Partition}:service:${AWS::Region}:..."` for ARNs (never hardcode `arn:aws:`)
- Use `!Sub "https://console.${AWS::URLSuffix}/..."` for console URLs
- See `docs/CLOUDFORMATION.md` for full details

## Validation Tools

- `scripts/validate_structure.py` — Checks recipe directory completeness
- `scripts/validate_metadata.py` — Checks metadata.yml schema conformance
- `scripts/validate_partitions.py` — Catches hardcoded `arn:aws:` patterns
- `cfn-lint` — CloudFormation template linting

## Pull Request Conventions

Title format: `[namespace/recipe] Description`
