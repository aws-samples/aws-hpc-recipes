# entra_id

## Info
The solution allows Entra ID users to log in to RES and use their VDIs by setting up a sync between Entra ID and the currently supported identity solution of AWS managed AD.

This architecture establishes a 3-way relationship between Entra ID, AWS IAM Identity Center, and an AWS Managed Active Directory. At a high level, Entra ID users are first synced to AWS IAM Identity Center via SAML and SCIM. The syncing events will trigger a custom Lambda function (via EventBridge) which handles the user creation/update/deletion in the AWS managed AD by running remote commands (via SSM) on the directory administration instance. Passwords for logging in to VDIs will be sent to AD user’s email (via SES). The custom Lambda can also be triggered manually via the AWS Lambda console for resetting a user’s password in the AD.

## Usage

### Prerequisites
1. Create an AWS Managed AD in the Directory Service console and set up a directory administration instance following https://docs.aws.amazon.com/directoryservice/latest/admin-guide/console_instance.html. Alternatively, deploy the RES external resource stack which includes these two required resources by default.
2. Configure SCIM synchronization between Microsoft Entra ID and IAM Identity Center following https://docs.aws.amazon.com/singlesignon/latest/userguide/idp-microsoft-entra.html. **DO NOT** enable automatic provisioning before you deploy the Entra ID template mentioned in the Deployment section below.
3. (Only if SES is in sandbox mode) Validate email addresses in the AWS SES console for sending and receiving AD user password.
4. Ensure the `EnableLdapIDMapping` input parameter is set to True when installing RES.

### Limitations
Users will have different passwords in Entra ID and AWS managed AD, since user passwords cannot be synced from Entra ID to AWS managed AD automatically. Users will use their Entra ID passwords to log in to the RES portal itself and then their password provided by AWS Managed AD for their desktop sessions. AWS account admins can reset the AD user password to sync with Entra ID, but it requires manual operations.

### Deployment
Download the CFN template’s JSON and deploy via the CFN console. The template requires the following input parameters:
* `Stack name` - Assign a name for the CloudFormation you are deploying
* `ManagedAdAdminPassword` - Password of the AD admin user
* `ManagedAdAdminUsername` - Username of the AD admin user (e.g. `<NetBIOS-name>\Admin`)
* `ManagedAdUsersOU` - Organizational unit within AD to sync the Entra ID users to. Suggest to use the same users OU when installing RES so that RES can sync all the users automatically.
* `SenderEmail` - Sender email address for sending password to AD users
* `ManagedAdUserGroup` - All the synced users will be added to the specified AD group automatically. Default value is `res`. You can log in to the directory administration instance and add users to any other AD groups manually after the sync.
* `WindowsManagementHostInstanceId` - EC2 instance ID of the directory administration instance

### How to test once your template is deployed

#### AD User Management

1. Add a new user with a valid email address in Entra ID. Make sure to verify the email in SES if SES is running in sandbox mode.
2. Wait for the added user to be synced to the Managed AD automatically (the synchronization happens every 40 minutes) or trigger the synchronization on demand in the Entra ID console. You will receive an email with the AD user password.
3. RES will sync AD users every hour by default.
4. Configure Entra ID as the identity provider and enable SSO in RES following https://docs.aws.amazon.com/res/latest/ug/configure-id-federation.html#configure-id-federation_config-idp
5. Log in to the RES portal, launch, and connect to a VDI using the AD user password (sent from email).

#### Tips and troubleshooting

* Update username/email in Entra ID: Verify that the user information is updated by checking the user detail via the directory administration instance or RES web portal.
* Reset a user’s password: go to the Directory Service console and use the Reset User Password option. Alternatively, you can trigger the AD management Lambda (deployed by the provided CFN template) manually via the AWS CLI or the Lambda console with the following event payload:
```
{"detail": {"eventName": "ResetPassword", "username": "<username>", "password": "<new_password>" }}
```

* Delete the user in Entra ID: Verify that the user is eventually deleted via the directory administration instance or RES web portal.

## Cost Estimate
The recipe depends on the following AWS services:
- AWS CloudFormation
- Amazon EventBridge
- AWS IAM Identity Center
- AWS CloudTrail
- AWS Lambda
- AWS Systems Manager 
- Amazon EC2
- AWS Directory Service
- Amazon Simple Email Service

The cost varies depending on the number of Entra ID users and frequency of the synchronization.

All the Entra ID users will be synced to an AWS Managed AD, so it will incur the cost of that resource as well.