# ARN and Console URL Regionalization Scripts

These scripts help make CloudFormation templates work across all AWS partitions, including GovCloud and other AWS partitions.

## Purpose

AWS has multiple partitions:
- `aws` - Standard AWS regions
- `aws-us-gov` - AWS GovCloud (US) regions
- `aws-cn` - AWS China regions
- `aws-iso` - AWS ISO regions
- `aws-iso-b` - AWS ISOB regions

By using the `AWS::Partition` and `AWS::URLSuffix` pseudo-parameters in CloudFormation templates, we can make our templates work across all AWS partitions without modification.

## Scripts

### 1. ARN Regionalization (`regionalize_arns.py`)

This script replaces hardcoded `arn:aws:` with `!Sub "arn:${AWS::Partition}:"` to make ARNs work in all AWS partitions.

### 2. Console URL Regionalization (`regionalize_console_urls.py`)

This script replaces hardcoded console URLs like `console.aws.amazon.com` with constructs that use `AWS::URLSuffix` to make console URLs work in all AWS partitions.

For example, in GovCloud regions:
- Standard URL: `https://us-gov-west-1.console.aws.amazon.com/ec2/home?region=us-gov-west-1`
- Correct URL: `https://us-gov-west-1.console.amazonaws-us-gov.com/ec2/home?region=us-gov-west-1`

## Usage

### Running the Scripts on All Templates

To run the ARN regionalization script on all CloudFormation templates:

```bash
python scripts/regionalize_arns.py
```

To run the console URL regionalization script on all CloudFormation templates:

```bash
python scripts/regionalize_console_urls.py
```

### Testing on a Single Template

To test the ARN regionalization script on a single template:

```bash
python scripts/test_on_template.py /path/to/template.yaml
```

To test the console URL regionalization script on a single template:

```bash
python scripts/test_on_console_urls_template.py
```

## How It Works

### ARN Regionalization

The script:

1. Finds all YAML files in the recipes directory
2. Identifies CloudFormation templates by looking for common indicators
3. Processes each template line by line
4. Replaces hardcoded ARNs with parameterized versions using `!Sub`
5. Preserves existing parameterized ARNs

### Console URL Regionalization

The script:

1. Finds all YAML files in the recipes directory
2. Identifies CloudFormation templates by looking for common indicators
3. Processes each template line by line
4. Replaces hardcoded console URLs with parameterized versions using `AWS::URLSuffix`
5. Preserves existing parameterized URLs

## Examples

### ARN Regionalization

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

### Console URL Regionalization

Before:
```yaml
Value: !Sub
  - https://${ConsoleDomain}/ec2/home?region=${AWS::Region}
  - { ConsoleDomain: !Sub '${AWS::Region}.console.aws.amazon.com' }
```

After:
```yaml
Value: !Sub
  - https://${ConsoleDomain}/ec2/home?region=${AWS::Region}
  - { ConsoleDomain: !Sub '${AWS::Region}.console.${AWS::URLSuffix}' }
```

## Limitations

- The scripts assume that ARNs and URLs are on their own line or with minimal context
- They may not handle complex nested structures correctly
- Manual verification of changes is recommended for critical templates