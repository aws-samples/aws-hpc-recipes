# PCS Slurm REST API with a Cognito-authenticated proxy

![Tags: pcs | cognito | lambda | apigateway | rest | iam | community](https://img.shields.io/badge/tags-pcs%20%7C%20cognito%20%7C%20lambda%20%7C%20apigateway%20%7C%20rest%20%7C%20iam%20%7C%20community-lightgrey)

## Info

This recipe deploys a REST-enabled AWS PCS cluster with an authenticating proxy in
front of the Slurm REST API. Once it is running, you submit and monitor Slurm jobs
over HTTPS from outside the VPC, and each job keeps the identity of the user who
sent it. The cluster nodes run in a private subnet, so the API is the way in for a
job submitter, not SSH.

Three components do the work. An Amazon Cognito User Pool authenticates the caller.
Amazon API Gateway verifies the Cognito token and applies an IP allowlist. An AWS
Lambda function inside the VPC then converts the verified identity into the token
that `slurmrestd` needs and forwards the request.

The important part is identity propagation. The recipe stores each demo user's
POSIX identity, which is the `uid`, `gid`, home directory, gecos field, and
supplementary groups, as Cognito custom attributes. When a request comes in, the
proxy reads these verified attributes and puts them into a new, enriched
`slurmrestd` JWT. That identity matches the Linux user the cluster creates on each
node, so a job sent as `alice` runs as the Linux user `alice`. The Cognito
attribute, the token claim, and the Linux account all agree, and that agreement is
the purpose of the recipe.

This is a recipe for demonstration and learning. It shows how the components work
together; it is not a production deployment. For the changes to make before real
work, refer to *Additional considerations*.

## Two roles: operator and API consumer

The recipe involves two different people. Keep them separate as you read this
document.

- **The operator** deploys and administers the system. They provide the EC2 SSH
  key, select the allowlists, and hold the `DemoUserPassword`. They use the PCS
  console and connect to the login node with AWS Systems Manager Session Manager.
  The nodes run in a private subnet, so Session Manager is the interactive path.
  The SSH key, the login node, the PCS console, and adding users (refer to
  *Managing users*) are all for the operator.
- **The API consumer** is the reason for the recipe. They have only a Cognito user
  name, a password, and the API Gateway URL. They submit and monitor jobs over
  HTTPS with `curl` or another HTTP client, and they never need SSH, an EC2 key,
  the PCS console, or AWS credentials.

Where this document mentions SSH, the login node, or the PCS console, those steps
are for the operator. The API consumer uses only a token and a URL.

## How it works

![Architecture: an API consumer calls API Gateway over HTTPS; the proxy Lambda in a
private subnet reads the caller's POSIX identity from the verified Cognito custom
attributes and mints an enriched JWT for slurmrestd, reached through the cross-account
PCS cluster ENI; a seed-demo-users node lifecycle action creates matching local Linux
users on the cluster nodes.](docs/architecture.png)

The diagram shows two colors of flow. The numbered dark path is a normal request. The
pink paths are identity: the caller authenticates against the Cognito User Pool on
first login, and the proxy reads the POSIX identity from the verified claims. The Slurm
controller and slurmrestd run in an AWS-managed account, reached from your VPC through
the cross-account PCS cluster ENI.

A request moves through four steps:

```
caller (curl + Cognito ID token, over HTTPS)
  -> API Gateway (REGIONAL REST API; TLS; Cognito authorizer; IP allowlist; throttling)
    -> proxy Lambda (in the private subnet)
      -> slurmrestd on the controller's private VPC IP, port 6820
        -> Slurm controller
```

API Gateway is the only public entry point. It uses its built-in
`COGNITO_USER_POOLS` authorizer to verify the caller's token against the User Pool,
then sends the verified claims to the proxy Lambda. The proxy Lambda is the only
component that connects to `slurmrestd`, which has a private IP only, is not
encrypted, and accepts connections on TCP 6820 only from inside the VPC. This
recipe does not make `slurmrestd` available outside the VPC.

Two facts are important for callers:

- **Send the Cognito ID token, not the access token.** The POSIX custom attributes
  are only in the ID token. The access token does not carry them, so a request
  authenticated with the access token leaves the proxy with no identity to use.
- **The proxy makes the token and converts the data types.** The Cognito claims
  arrive as strings, so the proxy converts the `uid` and `gid` to integers and the
  comma-separated `gids` to an array of integers. It then signs an HS256 JWT with
  the key PCS created when you enabled the REST API. It also replaces the incoming
  `Authorization` header, so the caller's Cognito token never reaches
  `slurmrestd`.

The proxy Lambda uses the PyJWT library to sign the token. The stack builds this
dependency when you deploy: an AWS CodeBuild project runs `pip install` in your
account, packages the handler with PyJWT, and puts the resulting zip in an Amazon
S3 bucket the stack owns. The Lambda runs from that zip.

## Prerequisites

- An AWS account and a Region that has AWS PCS.
- An Amazon EC2 SSH key pair in the Region. Refer to
  [Create a key pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair).
- Your public IP in CIDR format, for example `203.0.113.10/32`. The API Gateway
  allowlist uses it. To find your public IP, use a tool such as
  https://ifconfig.co/.
- The Slurm REST API, which needs Slurm 25.05 or a later version. The template
  fixes the cluster at Slurm 26.05, so there is nothing to select.

This recipe deploys into an existing VPC. Step 0 of the deploy explains how to stand
one up with the `net/hpc_large_scale` recipe if you do not already have one.

This recipe always enables Slurm accounting with a managed `slurmdbd`. AWS PCS
supports managed accounting in AWS commercial Regions and, since June 2026, in AWS
GovCloud (US). The recipe has been tested in commercial Regions.

## Deploy

Networking is a separate concern in HPC Recipes: you stand up a VPC once, then
deploy storage, clusters, and Lambdas into it. This recipe follows that model. Step 0
is the VPC (bring your own, or make one). Step 1 is the single `main.yaml` launch that
builds the cluster and the proxy inside that VPC.

### Step 0 - an existing VPC (bring your own, or make one)

This recipe deploys into an existing VPC. It does not build one. Give it a VPC with
two private subnets in two Availability Zones.

If you already run an HPC VPC, use it. Otherwise stand one up once with the
[`net/hpc_large_scale`](../../net/hpc_large_scale/) recipe, which provisions public
and private subnets across two Availability Zones. Note its VPC Id and two of its
private subnet Ids for Step 1.

### Step 1 - cluster and proxy (`main.yaml`)

This template composes two nested stacks:

- `cluster.yaml` builds the REST-enabled PCS cluster. It takes the VPC and subnets
  from Step 0 and adds EFS storage and the two demo users.
  Both node groups run in a private subnet.
- `proxy-cognito.yaml` builds the Cognito User Pool, API Gateway, and the proxy
  Lambda.

The cluster's outputs feed the proxy stack's parameters, so a single launch brings
up the whole demo. During deploy, a CodeBuild project builds the proxy Lambda's
package, which adds a few minutes to stack creation.

Use this quick-create link. Change the Region in the URL if you work in a different
Region.

[![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/quickcreate?templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/rest_api_cognito/assets/main.yaml)

The operator sets these parameters at launch:

- **VpcId**, **PrivateSubnetId0**, **PrivateSubnetId1** - the VPC and two private
  subnets from Step 0.
- **NodeArchitecture** - `x86` or `Graviton`. Defaults to `x86`.
- **KeyName** - the EC2 SSH key pair for the login node. This is for the operator
  only. The API consumer does not use it.
- **ClientIpCidr** - the IP range allowed to reach the login node over SSH. This is
  for the operator only. It is different from `AllowedCidr`, which controls the API.
- **AllowedCidr** - the IP range that can call the API Gateway endpoint. This is
  where your API consumers make requests. There is no default value. You must give
  an explicit range. Do not open the API to all addresses.
- **DemoUserPassword** - a `NoEcho` password for the demo users. There is no default;
  you must supply one at launch. The stack requires 8 to 127 characters with at least
  one uppercase letter, one lowercase letter, one number, and one special character, and
  no leading or trailing space. Do not include the user name in the password. The
  operator gives it to the person who acts as `alice` or `bob`.
- **JwtExpirySeconds** - the lifetime of each minted `slurmrestd` JWT. Defaults to
  120. The token is minted fresh per request and never returned to the caller, so a
  short lifetime is safe.

Make the stack name 40 characters or fewer. The recipe uses the stack name
as the PCS cluster name, and AWS PCS permits a maximum of 40 characters.

The recipe makes two demo users, `alice` and `bob`. By default, `alice` has the
`uid` and `gid` `1002`, and `bob` has the `uid` and `gid` `1003`. The Cognito
custom attributes and the Linux accounts on each node use the same values. These
same values keep the identity correct from end to end.

When the stack shows `CREATE_COMPLETE`, open its **Outputs** tab. You use
these outputs:

- **ApiGatewayUrl** - the base URL of the proxy.
- **CognitoClientId** - the app client ID for `initiate-auth`.
- **CognitoUserPoolId** - the User Pool ID.
- **PcsConsoleUrl** - the link to the cluster in the PCS console. Use it to connect
  to the login node.

## Usage: end-to-end smoke test

This procedure authenticates as a demo user, calls the REST API through the proxy,
submits jobs as two different users, and confirms that each job ran as the correct
identity.

Steps 1 to 4 are the API consumer's work and need only a token and `curl`. Step 5
is an operator check on the cluster; the API consumer does not do it. To follow
their own jobs, an API consumer uses the REST API instead, for example a `GET`
request to `/slurmdb/v0.0.44/jobs`, which returns the caller's own jobs by default.

The demo password is the `DemoUserPassword` you supply at launch (there is no
default). The same value is set for both `alice` and `bob`.

### 1. Authenticate and get the ID token

This proves Cognito authenticates the caller and issues the ID token the proxy
trusts as the credential for every later request.

Read the password into a shell variable rather than typing it into the command.
The prompt does not echo it, and it does not land in your shell history:

```bash
read -rsp 'Demo user password: ' DEMO_PW; echo

TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <CognitoClientId output> \
  --auth-parameters USERNAME=alice,PASSWORD="$DEMO_PW" \
  --query 'AuthenticationResult.IdToken' \
  --output text)
```

The variable stays in this shell session only. Run `unset DEMO_PW` when you are
done with the walkthrough.

Keep the **`IdToken`**. Do not keep the `AccessToken`. Only the ID token has the
custom attributes for the POSIX identity, and the proxy rejects anything that is
not an ID token.

### 2. Ping the API

This confirms the whole path works end to end before you submit real work.

```bash
curl -H "Authorization: Bearer $TOKEN" \
  <ApiGatewayUrl output>/slurm/v0.0.44/ping
```

A good response confirms that the caller was authenticated, the proxy minted a
valid JWT, and `slurmrestd` answered.

### 3. Submit a job as alice

This shows a job submitted over REST runs under the caller's own POSIX identity,
here `alice`.

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  <ApiGatewayUrl output>/slurm/v0.0.44/job/submit \
  -d '{
        "job": {
          "name": "hello-alice",
          "partition": "demo",
          "tasks": 1,
          "current_working_directory": "/tmp",
          "environment": ["PATH=/bin:/usr/bin"]
        },
        "script": "#!/bin/bash\nsleep 30\nid\nhostname"
      }'
```

The `partition` is the name of the cluster queue, `demo`. The `script` is a small
job that records its identity. The `environment` sets a minimal `PATH` that is
enough for this example. A real job usually needs more, such as `/usr/local/bin`
and your application's own paths, so treat this as a starting point rather than a
template to copy.

The compute node group starts at zero nodes. If none is running, the first job
starts one, so the job waits in the pending or `CONFIGURING` state for a few
minutes before it runs. This delay is normal, not a failure.

### 4. Submit a job as bob

This proves a second caller runs under a different identity, so the proxy maps each
token to its own POSIX user rather than a shared one. Authenticate again as `bob` to
get a new ID token, then submit the job again. Both demo users have the same
password, so this reuses `$DEMO_PW` from Step 1.

```bash
TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id <CognitoClientId output> \
  --auth-parameters USERNAME=bob,PASSWORD="$DEMO_PW" \
  --query 'AuthenticationResult.IdToken' \
  --output text)

curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  <ApiGatewayUrl output>/slurm/v0.0.44/job/submit \
  -d '{
        "job": {
          "name": "hello-bob",
          "partition": "demo",
          "tasks": 1,
          "current_working_directory": "/tmp",
          "environment": ["PATH=/bin:/usr/bin"]
        },
        "script": "#!/bin/bash\nsleep 30\nid\nhostname"
      }'
```

### 5. Confirm identity propagation on the cluster (operator step)

This is the payoff: it proves the identity in the token became the Linux user that
ran the job. This step is for the operator. The API consumer cannot do it and does
not need it. Open the **PcsConsoleUrl** output to go to the cluster in the PCS
console, find the
login node's EC2 instance, and choose **Connect** with AWS Systems Manager Session
Manager. On the node, run:

```bash
squeue          # jobs in flight, with their owners
sacct           # completed jobs, with their owners
```

The output shows `hello-alice` owned by `alice` and `hello-bob` owned by `bob`,
which confirms that the Cognito identity reached the Slurm accounting records.

The `v0.0.44` segment in the paths above is the version of the Slurm REST API. Each
Slurm release documents its own versions. `v0.0.44` is the version for Slurm 25.11,
the default of this recipe. If you deploy a different Slurm version, find the
correct segment in the
[Slurm REST API reference](https://slurm.schedmd.com/rest_api.html) for that
release. The proxy forwards the path unchanged, so it works with whatever version
your cluster supports.

## Managing users

The recipe supplies two demo users, `alice` and `bob`. Adding a third user shows
the main limit of the custom-attribute method. Read this section before you extend
the demo.

The POSIX identity of a user lives in **two separate places**. No component keeps
them the same automatically:

1. **In Cognito**, as the custom attributes of the user. These are `custom:uid`,
   `custom:gid`, `custom:gecos`, `custom:home`, and `custom:gids`. The proxy reads
   these attributes and puts them into the `slurmrestd` token.
2. **On the cluster nodes**, as a real Linux account. The account has an equal
   `uid` and `gid` and a home directory. The job runs as this account.

To add `carol`, the operator does two things: create `carol` in the Cognito User
Pool with the custom attributes, and make sure a Linux account `carol` with the
same `uid`, `gid`, and a home directory exists on the nodes. In this recipe the
`seed-demo-users` node lifecycle action creates the accounts on the nodes. It
ships in this recipe at
[`assets/seed-demo-users-v1.0.0.sh`](assets/seed-demo-users-v1.0.0.sh) and it holds
fixed values for `alice` and `bob`, so a real third user also means editing that
script.

The two places can disagree. If the Cognito `custom:uid` does not match `id carol`
on the node, you get a silent identity mismatch. To surface exactly this, the seed
script writes a warning to its log whenever it finds an account whose `uid` or
`gid` differs from the requested value.

Home directories share the same root cause. The AWS-maintained `configure-efs-homes`
lifecycle action mounts the shared EFS at `/home`, but it does not create the
per-user home directories. A job from the REST API never does an interactive login,
so nothing creates a home directory on the user's behalf, and a job whose work
directory is a missing home directory fails (Slurm `RaisedSignal:53`). The
`seed-demo-users` action therefore creates the home directories and sets their owner
itself. This is not a defect in `configure-efs-homes`. That action provides the
mount, and the seeder fills in the accounts and directories the REST path needs.

Both chores come from one design choice: this recipe materializes identity on each
node rather than resolving it from a single source. That fits the small set of demo
users it ships with. A large user population is where a directory service earns its
keep, because a user is defined once and the nodes read the `uid`, `gid`, and home
directory directly.

## Troubleshooting

**504 or timeout.** The proxy could not connect to `slurmrestd`. Check this first:
make sure the cluster security group permits inbound traffic on TCP 6820 from the
proxy Lambda's security group. The proxy stack adds this rule, so it should already
be present. The proxy also recovers on its own after a Slurm controller restart. If
the controller moved and `slurmrestd` came back on a new private IP, the proxy
clears its cache and reads the endpoint again on the next request, so a second call
often succeeds.

**401 or 403 at the API Gateway edge.** The token is not valid for one of these
reasons. The token expired; run `initiate-auth` again. Or you sent the
`AccessToken` and not the `IdToken`. Or your source IP is not in `AllowedCidr`.

**403 saying `User: anonymous is not authorized ... no resource-based policy
allows` after you change `AllowedCidr`.** A new value for `AllowedCidr` updates the
API's resource policy, but API Gateway reads that policy when the API is deployed to
a stage, and a stack update does not redeploy it. The old CIDR stays in force. Deploy
the stage again:

```bash
aws apigateway create-deployment --rest-api-id <api id> --stage-name prod
```

Take the API id from the first part of the `ApiGatewayUrl` output. Allow up to two
minutes after the redeploy for the new policy to take effect, and re-test rather than
assuming the first call after it tells you anything.

This does not apply to a fresh deploy, where the policy is in force from the start.

**403 from a network whose address changes.** A corporate VPN or a cloud desktop can
send each request from a different address, so a `/32` in `AllowedCidr` matches only
some of the time. Check the address you actually egress from, for example with
`curl https://checkip.amazonaws.com`, and give `AllowedCidr` a range that covers it.

**Job rejected.** Make sure the `partition` in your job matches the name of the
queue. The name of the queue is `demo`.

## FAQ

**Why put a proxy in front of `slurmrestd` instead of exposing it directly?**
`slurmrestd` speaks plain HTTP, has no IP allowlist of its own, and trusts any
correctly signed JWT completely. It is built to sit on a trusted network, not on
the public internet. The proxy adds the parts a public endpoint needs: TLS, a
Cognito check, an IP allowlist, and request throttling. It also keeps
`slurmrestd` on a private IP so nothing outside the VPC can reach it.

**Why does the caller send a token but the proxy builds a different one?**
The Cognito ID token proves who the caller is and carries their POSIX attributes,
but `slurmrestd` does not accept Cognito tokens. It accepts only a JWT signed with
the cluster's own key. The proxy reads the verified Cognito claims and mints that
second token, so the caller never holds a credential that `slurmrestd` trusts and
the caller's token never reaches `slurmrestd`.

**Why are POSIX attributes stored in Cognito, and is that a good idea?**
It is fine for a demo because it keeps the recipe self-contained: no directory to
run, and the whole identity travels in the verified ID token. It does not scale.
The same `uid` and `gid` have to be typed into two places, Cognito and the node
seeder, and nothing keeps them in agreement. A large user population is better
served by a directory service that the nodes resolve directly.

**Why is the VPC a separate step?** Networking is a shared, slow-changing concern in
HPC Recipes: you stand up a VPC once with `net/hpc_large_scale` (or bring your own),
then deploy storage, clusters, and Lambdas into it. Keeping the VPC out of this recipe
lets you tear down and rebuild the cluster and proxy against the same network without
waiting for a VPC each time. This recipe has no directory to stand up, so `main.yaml`
is the only launch.

**How do I add a real user?** Follow *Managing users*. In short, create the user in
Cognito with the five custom attributes, and add a matching Linux account with the
same `uid` and `gid` on the nodes by editing the `seed-demo-users` script. Keep the
two in agreement.

## Additional considerations

This is a recipe for teaching. Before you use a system like it for real work, think
about these changes:

- **A directory service for identity at scale.** Cognito custom attributes are
  convenient for a demo. They do not scale to a large user population, and they
  duplicate identity across Cognito and the node seeder. A production system with
  many users resolves POSIX identity from a directory service, so a user is defined
  once and the nodes read it directly.
- **Choose a strong `DemoUserPassword`.** There is no default; you set your own value
  at launch (the stack rejects values that do not meet the password policy). For real
  use, add your own users to Cognito rather than reusing the demo accounts.
- **Shorter Cognito token lifetimes.** The User Pool app client controls the ID
  token lifetime for the caller. Shorten it to reduce the window a lost token is
  usable. The `slurmrestd` JWT is already short (`JwtExpirySeconds`), and the proxy
  never returns it to the caller.
- **AWS WAF in front of API Gateway.** Add rate-based and managed rules. They work
  together with the IP allowlist and the stage throttling that this recipe sets.
- **Access logging.** This recipe does not enable API Gateway or S3 access logging, to
  keep it minimal: API Gateway access logging needs a region-wide `AWS::ApiGateway::Account`
  CloudWatch role (which changes account state beyond this stack), and the build-artifact
  bucket is transient. For production, enable API Gateway access logging to a CloudWatch log
  group and S3 server access logging to a dedicated log bucket.
- **Key rotation.** Rotate the secrets. Do not keep them static.
- **Narrow the node role's Amazon S3 access.** The nodes read one object, the
  `seed-demo-users` lifecycle script, through `AmazonS3ReadOnlyAccess`, which grants
  read on every bucket in the account. Replace it with an inline policy for
  `s3:GetObject` on that one object ARN.
- **Audit who can read the JWT signing key.** The proxy's role grants
  `secretsmanager:GetSecretValue` on the `pcs!*` name prefix, because PCS chooses the
  secret name and it is not known when the template is written. Anyone who reads that
  secret can forge a token that `slurmrestd` fully trusts. After the stack is up,
  narrow the grant to the one secret ARN that `pcs:GetCluster` reports, and check that
  no other role in the account holds a broad `pcs!*` read.

Three safeguards are already built in. Self-registration is off: the User Pool sets
`AllowAdminCreateUserOnly: true`, so only the seeder creates users, not the public
sign-up API. The proxy refuses to mint a system or privileged identity: it rejects any
`uid` or `gid` below 1000, even if a claim asserts one, so a token can never map a job
to root. And the proxy accepts only a Cognito ID token: it checks the `token_use`
claim rather than trusting that the authorizer forwards nothing else.

## Cleaning up

Delete the `main.yaml` stack from the AWS CloudFormation console. The cluster and
proxy stacks are nested below it, so deleting it removes both. The demo Cognito users
are removed automatically: the user-seeder custom resource deletes `alice` and `bob`
as the proxy stack tears down. The VPC is a separate stack (Step 0); delete it last,
and only if you created it for this recipe and nothing else uses it.

## Glossary

### JWT signing key
The symmetric (HS256) secret that `slurmrestd` uses to validate REST API tokens.
PCS **generates it automatically** when the REST API is enabled and stores it in
AWS Secrets Manager. It is retrieved at runtime from
`GetCluster` -> `slurmConfiguration.jwtAuth.jwtKey.secretArn`. Distinct from the
cluster secret.

### cluster secret
The `slurmConfiguration.authKey` secret, Slurm's daemon-to-daemon shared
authentication key (controller/compute/dbd). **Not** used for REST API tokens.
Signing a REST token with this key produces a token `slurmrestd` rejects. Named
here only to prevent confusion with the JWT signing key.

### enriched JWT
The REST API bearer token minted by the proxy Lambda. Beyond standard claims
(`exp`, `iat`) it carries full POSIX identity: `sun` (username), `uid`, `gid`,
and `id.{gecos,dir,shell,gids}`. "Enriched" distinguishes it from a bare
username-only token, which PCS `slurmrestd` does not accept.

### POSIX identity
A user's Linux account facts: `uid`, `gid`, home directory, gecos, supplementary
`gids`. In this recipe it originates as Cognito custom attributes, is stamped
into the enriched JWT, and must match the actual Linux user created on the
compute node by the seed-demo-users lifecycle action. The three must agree, and
that agreement is the recipe's central invariant.

### authenticate vs. resolve identity
Two separate steps this recipe keeps distinct. **Authenticate** = prove the caller
is a valid Cognito principal (the authorizer's job). **Resolve
identity** = determine that principal's POSIX identity, which this recipe reads from
the verified token claims. Conflating them is the mistake the source blog makes with
its `?user=alice` query string.

### authorizer
The API Gateway built-in `COGNITO_USER_POOLS` authorizer (not a Lambda). API
Gateway natively verifies the Cognito **ID token**'s RS256 signature and expiry,
then passes the verified POSIX identity claims to the integration at
`event.requestContext.authorizer.claims`. Custom attributes ride only in the ID
token, so callers send the ID token as the bearer. The built-in authorizer performs
this verification directly, so the recipe adds no custom authorizer Lambda.

### proxy Lambda
The in-VPC Lambda that mints the enriched JWT and forwards the request to the
private `slurmrestd` endpoint on port 6820. The only component that reaches
`slurmrestd`. Also the sole owner of **type coercion**: the verified Cognito
claims arrive as strings, so the proxy casts `uid`/`gid` to JSON integers and
parses the comma-delimited `custom:gids` string into a JSON integer array before
signing the enriched JWT. The authorizer only verifies and forwards claims;
it never builds typed values.

### slurmrestd endpoint
The PCS-managed Slurm REST HTTP server. Private-IP-only, plaintext (no TLS), port
6820. Never exposed outside the VPC by this recipe. Reached only by the
proxy Lambda. Its address comes from `GetCluster` -> `endpoints[]` where
`type == SLURMRESTD`.
