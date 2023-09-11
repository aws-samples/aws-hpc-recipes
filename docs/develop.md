# Developing Recipes

## Makefile

Most project build processes are defined and controlled in the top-level Makefile. There are three main targets you should be aware of for day-to-day use.
* `build`: Iterate through the recipes and run their default `make build` target.
* `test`: Iterate through the recipes and run their default `make test` target.
* `deploy`: This is the main target you as a recipe developer will care about. It drives the workflow for synchronizing the contents of the repository out to an S3 bucket. By default, it's configured to deploy to the project's S3 bucket, but that can be overridden with environment variables. You will need to do so as a contributor as you will not have access to the projet's deployment assets. 

## Deploy recipes to your own S3 bucket

First, create an S3 bucket. This should be dedicated to your work with the HPC recipes library as it will contain world-readable files. 

You can configure the destination and path for your HPC recipes library deployment as follows:
* Set `HPCDK_TAG` to the branch name you are deploying from
* Set `HPCDK_S3_BUCKET` to the name of your personal bucket
* Set `HPCDK_PROFILE` to your preferred AWS CLI credentials profile is

Here's an example that illustrates all three options:

`HPCDK_TAG=develop HPCDK_S3_BUCKET=MYDEVBUCKET HPCDK_PROFILE=yakshaver make deploy`

This will use AWS credentials from the local profile nicknamed "yakshaver" to deploy assets found under the `recipes` directory to:
* AWS S3 HTTP URL - https://MYDEVBUCKET.s3.us-east-2.amazonaws.com/develop/
* AWS S3 protocol - s3://MYDEVBUCKET/develop/

