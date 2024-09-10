# Usage

Use the script `set_variables.sh` to create a temporary variables file. This allows
the Packer template to, in conjuction with the shell scripts in this repo, to 
work with operating systems that are supported by AWS PCS. 

Valid values for the distribution include:
* `amzn`
* `rhel`
* `rocky`
* `ubuntu`

```shell
packer build \
  -var "hpc_recipes_s3_bucket=aws-hpc-recipes-dev" \
  -var "hpc_recipes_s3_branch=pcs-ib" \
  -var-file <(./set_variables.sh amzn) \
  template.json
```
