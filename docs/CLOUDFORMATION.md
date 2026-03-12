# CloudFormation Rules

## Partition Safety (Enforced by CI)

All templates must work across AWS partitions: standard (`aws`), GovCloud (`aws-us-gov`), and China (`aws-cn`).

### ARNs — Never hardcode `arn:aws:`

```yaml
# WRONG — breaks in GovCloud and China
- arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# CORRECT — works everywhere
- !Sub arn:${AWS::Partition}:iam::aws:policy/AmazonSSMManagedInstanceCore
```

### Console URLs — Never hardcode `amazonaws.com`

```yaml
# WRONG
https://console.aws.amazon.com/cloudformation/home

# CORRECT
!Sub "https://console.${AWS::URLSuffix}/cloudformation/home"
```

The `scripts/validate_partitions.py` linter enforces these rules. It scans all YAML/JSON files under `assets/` for hardcoded partition strings.

### Known Exceptions

Some ARNs are genuinely partition-specific (e.g., SNS topics owned by AWS in a fixed region). Mark these with a comment:

```yaml
# partition-exception: AWS-owned SNS topic, only exists in us-west-2
TopicArn: arn:aws:sns:us-west-2:767397762724:dlami-updates
```

## Parameter Best Practices

- Use `AllowedValues` for enumerated choices
- Use `AllowedPattern` with `ConstraintDescription` for string validation
- Provide sensible `Default` values where possible
- Write clear `Description` for every parameter

## Output Best Practices

- Always output resource IDs, ARNs, and relevant console URLs
- Use `Export` for values consumed by other stacks
- Name exports with the stack name prefix to avoid collisions

## Common Patterns

- **Quick-launch links**: Use S3-hosted template URLs with region-specific console links
- **Conditions**: Use for optional resources or region-specific logic
- **DependsOn**: Use when implicit dependencies aren't sufficient
- **Nested stacks**: Reference other HPC recipe assets via their S3 URLs
