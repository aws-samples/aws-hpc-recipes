# Public Certificate Generation for Route53 Domains

## Info

This recipe will use Let's Encrypt to generate public certificates for a Amazon Route53 owned domain.

This is useful when you have an application that needs the .pem/.key files for a certificate for a public domain stored in AWS Secrets Manager.

## Background

This recipe includes a single CloudFormation template that generates a certificate, uploads the files to a secret. It uses a subnet for an instance to perform the certificate creation.

It uses the [acme.sh](https://github.com/acmesh-official/acme.sh) script to geneate the certs.

### Usage

You can launch this template by following this quick-create link:

* Create [Public Certificates](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=public-certs&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/cert/public_certs/assets/main.yaml)

If you don't wish to use the quick-create link, you can also download the [assets/main.yaml](assets/main.yaml) file and uploading it to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation).

**NOTE**: The certificate lifetime is 60 days and there is no mechanism for renewal. This is for demonstration purposes and a more complete solution is needed for certificate renewal.

## Cost Estimate

* Instance - No Charge after stack creation
* Secrets - You pay a small amount per month for each of the secrets as well as each API access.

See [AWS Secrets Manager pricing](https://aws.amazon.com/secrets-manager/pricing/) for details.

## Cleaning Up

When you are done using this configuration, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack.
