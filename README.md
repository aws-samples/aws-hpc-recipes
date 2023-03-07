# HPC Development Kit (HPCDK)

This is a prototype library of interoperable blueprints for HPC infrastructure.

## Using

Deploy resources in the `resources/` directory using CloudFormation. 

## Developing

1. Install and configure the AWS CLI
2. Install [cfn-lint](https://github.com/aws-cloudformation/cfn-lint)
3. Create an S3 bucket `S3_BUCKET_NAME` to hold Cloudformation assets
4. (Optional) Lint any new or updated CloudFormation templates with cfn-lint
5. Deploy to the bucket with `aws s3 sync --acl public-read resources s3://S3_BUCKET_NAME/resources/`
