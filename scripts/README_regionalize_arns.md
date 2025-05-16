# ARN Regionalization Script

This script helps regionalize ARNs in CloudFormation templates to support GovCloud and other AWS partitions. It replaces hardcoded `arn:aws:` with `!Sub "arn:${AWS::Partition}:"` to make templates work in all AWS partitions.

## Purpose

AWS has multiple partitions:
- `aws` - Standard AWS regions
- `aws-us-gov` - AWS GovCloud (US) regions
- `aws-cn` - AWS China regions
- `aws-iso` - AWS ISO regions
- `aws-iso-b` - AWS ISOB regions

By using the `AWS::Partition` pseudo-parameter in CloudFormation templates, we can make our templates work across all AWS partitions without modification.

## Usage

### Running the Script on All Templates

To run the script on all CloudFormation templates in the repository:

```bash
python scripts/regionalize_arns.py
```

This will:
1. Find all YAML files in the recipes directory
2. Identify which ones are CloudFormation templates
3. Replace hardcoded ARNs with parameterized versions
4. Print a summary of changes made

### Testing on a Single Template

To test the script on a single template:

```bash
python scripts/test_on_template.py /path/to/template.yaml
```

## How It Works

The script:

1. Finds all YAML files in the recipes directory
2. Identifies CloudFormation templates by looking for common indicators
3. Processes each template line by line
4. Replaces hardcoded ARNs with parameterized versions using `!Sub`
5. Preserves existing parameterized ARNs

## Examples

Before:
```yaml
ManagedPolicyArns:
  - "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
```

After:
```yaml
ManagedPolicyArns:
  - !Sub "arn:${AWS::Partition}:iam::aws:policy/AmazonS3ReadOnlyAccess"
```

## Limitations

- The script assumes that ARNs are on their own line or with minimal context
- It may not handle complex nested structures correctly
- Manual verification of changes is recommended for critical templates