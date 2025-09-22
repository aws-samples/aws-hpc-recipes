# AWS HPC Recipes

## Project Overview

This repository contains 100+ infrastructure-as-code recipes for High Performance Computing (HPC) on AWS. Each recipe includes CloudFormation templates, documentation, and assets for deploying HPC infrastructure using services like AWS Parallel Computing Service (PCS), ParallelCluster, Research and Engineering Studio (RES), and AWS Batch.

## Repository Structure

- `recipes/` - Main recipe collection organized by service/category
  - `pcs/` - AWS Parallel Computing Service recipes
  - `pcluster/` - AWS ParallelCluster recipes  
  - `storage/` - Storage solutions (EFS, FSx, S3)
  - `net/` - Networking configurations
  - `res/` - Research and Engineering Studio recipes
  - `batch/` - AWS Batch recipes
  - `db/` - Database management recipes
  - `dir/` - Directory services recipes
  - `security/` - Security configurations
  - `training/` - Educational recipes
- `scripts/` - Python utilities for recipe management
- `templates/` - Jinja2 templates for generating recipe documentation
- `docs/` - Development and contribution documentation

## Recipe Structure

Each recipe follows this standard structure:
```
recipes/<namespace>/<recipe_name>/
├── README.md           # Recipe documentation
├── metadata.yml        # Recipe metadata (tags, description, etc.)
├── Makefile           # Build and test commands
├── assets/            # CloudFormation templates and other files
├── docs/              # Additional documentation
└── tests/             # Test files
```

## Development Commands

- **Create new recipe**: `python scripts/new_recipe.py <namespace> <recipe_name>`
- **Render README files**: `python scripts/render_readme.py`
- **Run tests**: `python run_test.py` (validates CloudFormation templates)
- **Check instance availability**: `python scripts/instance_region.py`

## CloudFormation Best Practices

- Use `AWS::Partition` pseudo-parameter for ARNs to support all AWS partitions (standard, GovCloud, China)
- Use `AWS::URLSuffix` for console URLs to work across partitions
- Include comprehensive parameter descriptions and constraints
- Add meaningful resource descriptions
- Follow least-privilege IAM principles
- Test stack creation AND deletion

## Code Style Guidelines

- **YAML**: Use 2-space indentation, quote strings when necessary
- **Python**: Follow PEP 8 conventions, use type hints where appropriate
- **Markdown**: Use consistent heading levels, include code blocks with language specification
- **Comments**: Liberally comment CloudFormation templates and scripts

## Testing Instructions

- All CloudFormation templates must validate using `aws cloudformation validate-template`
- Test both stack creation and deletion in a clean AWS account
- Verify cross-region compatibility where applicable
- Check that quick-launch links work correctly
- Ensure all referenced AMIs and resources are available in target regions

## Security Considerations

- Never commit AWS credentials or secrets
- Use AWS Secrets Manager or Parameter Store for sensitive data
- Follow principle of least privilege for IAM roles and policies
- Validate that security groups have appropriate restrictions
- Use `git-secrets` to scan for accidentally committed credentials

## Recipe Metadata Requirements

Each `metadata.yml` must include:
```yaml
name: recipe-name
description: Brief description of what the recipe does
tags:
  - service-name
  - technology
  - maturity-level  # core, beta, community
namespace: category-name
```

## Pull Request Guidelines

- Title format: `[namespace/recipe] Description`
- Test recipe deployment before submitting
- Update documentation if adding new features
- Ensure all CloudFormation templates pass validation
- Include rationale for new dependencies or AWS services
- Verify cross-region compatibility claims

## Common Patterns

- **Quick-launch links**: Use S3-hosted templates with region-specific console URLs
- **Parameter validation**: Use AllowedValues, AllowedPattern, and ConstraintDescription
- **Outputs**: Always include relevant resource IDs, ARNs, and console URLs
- **Dependencies**: Use DependsOn when implicit dependencies aren't sufficient
- **Conditions**: Use for optional resources or region-specific logic

## Troubleshooting

- **Template validation errors**: Check YAML syntax and CloudFormation resource properties
- **Stack creation failures**: Review CloudFormation events and logs
- **Permission errors**: Verify IAM policies have required permissions
- **Resource limits**: Check AWS service quotas in target regions
- **Cross-region issues**: Ensure AMIs and resources exist in all target regions

## Asset URLs

Templates are mirrored to S3 for CloudFormation access:
- HTTPS: `https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/<namespace>/<recipe>/assets/<file>`
- S3: `s3://aws-hpc-recipes/main/recipes/<namespace>/<recipe>/assets/<file>`
