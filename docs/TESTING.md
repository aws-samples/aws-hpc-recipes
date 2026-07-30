# Testing & Validation

## Automated Validation (CI)

The GitLab CI pipeline runs these checks on every merge request:

### 1. Recipe Structure Validation (`scripts/validate_structure.py`)
Verifies every recipe directory contains the required files:
- `README.md`, `metadata.yml`, `Makefile`, `assets/`, `docs/`, `tests/`

### 2. Metadata Validation (`scripts/validate_metadata.py`)
Checks that every `metadata.yml`:
- Contains all required fields (`name`, `version`, `description`, `tags`, `type`)
- Uses a valid namespace (defined in `config/metadata/values.yml`)
- Has a parseable semantic version
- Has a non-empty description and tags list

### 3. Partition Safety (`scripts/validate_partitions.py`)
Scans CloudFormation templates for hardcoded partition strings:
- `arn:aws:` without `${AWS::Partition}`
- Lines marked with `# partition-exception:` are excluded

### 4. ShellCheck (`scripts/validate_shellcheck.py`)
Runs [ShellCheck](https://github.com/koalaman/shellcheck) on recipe shell scripts with a two-tier policy:
- **Strict (blocking):** scripts under `recipes/pcs-scripts/` must pass cleanly.
- **Advisory (non-blocking):** scripts elsewhere are reported at `warning` severity but do not fail the build.

Vendored/generated scripts (e.g. under `.terraform/`) are skipped.

### 5. CloudFormation Linting (`cfn-lint`)
Runs `cfn-lint` on all `.yaml` and `.json` files under `assets/` directories.

## Running Validation Locally

```bash
# Run all validators
make validate

# Run individually
python -m scripts.validate_structure
python -m scripts.validate_metadata
python -m scripts.validate_partitions
python -m scripts.validate_shellcheck   # set SHELLCHECK_OPTIONAL=1 to skip if shellcheck is not installed
```

## Manual Testing Checklist

Before submitting a recipe:
- [ ] Stack creates successfully in a clean account
- [ ] Stack deletes cleanly (no orphaned resources)
- [ ] Cross-region compatibility verified (if claimed)
- [ ] Quick-launch links work correctly
- [ ] Referenced AMIs exist in target regions
