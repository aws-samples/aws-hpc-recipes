# RES `res:User` Tag for VDI Desktops

## Info

Adds a `res:User` cost-allocation tag (value = the RES session owner's username)
to VDI/DCV desktop EC2 instances **at launch**, enabling user-level cost
allocation alongside `res:Project`. This is an **interim** solution that requires
**no change to RES source**, intended for use until RES adds the tag natively.

Two solutions are provided — pick one:

| | Solution A — on-host script | Solution B — CloudFormation stack |
|---|---|---|
| Scope | Per project (opt-in) | Account-wide (all RES envs, all DCV hosts) |
| New infrastructure | None | Lambda + EventBridge + IAM role |
| Owner source | Local `OWNER_ID` on the host | RES `user-sessions` DynamoDB GSI |
| When applied | During VDI configuration | Shortly after instance reaches `running` |
| Tag credentials | Host `bootstrap_profile` | Dedicated Lambda role |

Both solutions are **environment- and version-agnostic**: they work unchanged
across a blue/green pattern (res-blue, res-green, future environments) and require
no edit when you install or upgrade a RES environment. Solution A's scripts contain
no environment name; Solution B's single stack derives the environment from each
instance's `res:EnvironmentName` tag, so one deployment per account covers every
environment.

> **Required for both:** after deployment, activate `res:User` as a
> [cost allocation tag](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/activating-tags.html)
> in AWS Billing. Until activated, the tag will not appear in Cost Explorer / CUR.

## Solution A — on-host script (recommended)

The desktop tags itself during VDI configuration using the host's existing
`bootstrap_profile` credentials (no new IAM).

1. Upload the script for each OS in scope to an S3 bucket the desktop can read
   (or host via HTTPS):
   ```bash
   aws s3 cp assets/tag-res-user.sh  s3://<your-bucket>/res-user/tag-res-user.sh
   aws s3 cp assets/tag-res-user.ps1 s3://<your-bucket>/res-user/tag-res-user.ps1
   ```

   > **Tag the S3 objects.** For an `s3://` script location, the VDI host's IAM
   > role can only download the object if it is tagged
   > `res:EnvironmentName=<your-environment-name>`. Without this tag, the download
   > fails with `AccessDenied`, the script silently does not run, and no `res:User`
   > tag is applied. Tag each object after upload:
   > ```bash
   > aws s3api put-object-tagging --bucket <your-bucket> --key res-user/tag-res-user.sh \
   >   --tagging 'TagSet=[{Key=res:EnvironmentName,Value=<your-environment-name>}]'
   > ```
   > See [Add launch scripts to a project](https://docs.aws.amazon.com/res/latest/ug/project-launch-template.html).
   > Alternatively, host the script over `https://` (reachable from the host), which
   > has no S3 object-tag requirement.
2. In the RES project configuration, register the script on the
   **`on_vdi_configured`** event for each OS:
   - Linux: `scripts.linux.on_vdi_configured` →
     `s3://<your-bucket>/res-user/tag-res-user.sh`
   - Windows: `scripts.windows.on_vdi_configured` →
     `s3://<your-bucket>/res-user/tag-res-user.ps1`
3. Launch a new desktop in that project and confirm the `res:User` tag appears on
   the instance.

Notes:
- New launches only — existing running desktops are tagged when next relaunched.
- The scripts fail safe: if the owner or credentials can't be resolved, they log a
  warning and exit successfully, never failing desktop configuration.

## Solution B — CloudFormation stack (cluster-wide)

Tags every RES DCV host in the account, regardless of project or environment.
**Deploy once per account** — it covers res-blue, res-green, and any environment
you add later, with no parameters and nothing to change on RES upgrade.

```bash
aws cloudformation deploy \
  --template-file assets/res-user-tagger.yaml \
  --stack-name res-user-tagger \
  --capabilities CAPABILITY_IAM
```

The Lambda tags any instance whose tags include
`res:NodeType=virtual-desktop-dcv-host`, deriving the RES environment from the
instance's own `res:EnvironmentName` tag and querying that environment's
`{env}.vdc.controller.user-sessions` table for the owner. Deploy the stack in the
same region as your RES environment(s); for multi-region, deploy once per region.

## Testing

```bash
make test   # shellcheck (Linux script) + cfn-lint (template) + pytest (Lambda)
```

The Windows PowerShell script is validated statically and via manual end-to-end
test (launch a Windows desktop with the script registered and confirm the tag).

## Retirement

When RES ships the native `res:User` tag, retire this recipe:
- Solution A: remove the `on_vdi_configured` entries from the project(s).
- Solution B: `aws cloudformation delete-stack --stack-name res-user-tagger`.
