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

## Ansible

Use [ansible-lint](https://github.com/ansible/ansible-lint) to check playbooks for practices and behavior that could potentially be improved.

## Terraform

Configure [tflint](https://github.com/terraform-linters/tflint) with the rules for Terraform Language and the [AWS ruleset](https://github.com/terraform-linters/tflint-ruleset-aws) to check Terraform files.

