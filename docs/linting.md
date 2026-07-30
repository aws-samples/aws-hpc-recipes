# Linting / Validation

## Secrets / Credentials

Avoid leaking secrets and credentials by running [Gitleaks](https://github.com/gitleaks/gitleaks).

## CloudFormation

Run [cfn_nag](https://github.com/stelligent/cfn_nag) on CloudFormation templates to look for indications of insecure infrastructure. Run [cfn-lint](https://github.com/aws-cloudformation/cfn-lint) (if your IDE doensn't already do it) to check your templates against the [AWS CloudFormation Specification](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-resource-specification.html)

## Python

Use [Bandit](https://bandit.readthedocs.io/en/latest/) to find common security issues in Python code.

## Dockerfiles

Lint your Dockerfiles with [hadolint](https://hadolint.github.io/hadolint/)

## UNIX shell scripts

Run [shellcheck](https://github.com/koalaman/shellcheck) to perform static analysis on Bash/Sh family shell scripts.

ShellCheck is enforced by CI via `scripts/validate_shellcheck.py` (part of `make validate`), with a two-tier policy:

- **Strict (blocking):** every shell script under `recipes/pcs-scripts/` **must** pass ShellCheck cleanly at default severity. A finding fails the build.
- **Advisory (non-blocking):** shell scripts elsewhere are checked at `warning` severity and findings are reported for awareness, but do not fail the build. Please clean these up when you touch the surrounding code.

Vendored or generated scripts (for example, Terraform module internals under `.terraform/`) are skipped. Locally, set `SHELLCHECK_OPTIONAL=1` to skip the check if the `shellcheck` binary is not installed (`make validate` does this automatically); CI always installs and runs it.

## Ansible

Use [ansible-lint](https://github.com/ansible/ansible-lint) to check playbooks for practices and behavior that could potentially be improved.

## Terraform

Configure [tflint](https://github.com/terraform-linters/tflint) with the rules for Terraform Language and the [AWS ruleset](https://github.com/terraform-linters/tflint-ruleset-aws) to check Terraform files.

