# entra_id

## Info

The recipe sets up Entra ID with RES so that Entra ID users can login to RES and use their VDIs. 

It establishes a 3-way relationship between Entra ID, AWS IAM Identity Center, and an AWS Managed Active Directory. At a high level, Entra ID users are first synced to AWS IAM Identity Center via SAML and SCIM. The syncing events will trigger a custom Lambda function (via EventBridge) which handles the user creation/update/deletion in the AWS managed AD by running remote commands (via SSM) on the directory administration instance. Passwords for signing into VDIs will be sent to AD user’s email (via SES). The custom Lambda can also be triggered manually via the AWS Lambda console for resetting a user’s password in the AD.

## Usage

### Prerequisites
1. Create an AWS Managed AD in the Directory Service console and set up a directory administration instance following https://docs.aws.amazon.com/directoryservice/latest/admin-guide/console_instance.html. Alternatively, deploy the RES external resource stack which includes these two required resources by default.
2. Configure SCIM synchronization between Microsoft Entra ID and IAM Identity Center following https://docs.aws.amazon.com/singlesignon/latest/userguide/idp-microsoft-entra.html. DO NOT enable automatic provisioning before you deploy the Entra ID template mentioned in the Deployment section below.
3. (Only if SES is in sandbox mode) Validate email addresses in the AWS SES console for sending and receiving AD user password.
4. Ensure the EnableLdapIDMapping input parameter is set to True when installing RES.
### Deployment

Deploy via the provided CloudFormation template. The template requires the following input parameters:
* `Stack name` - Assign a name for the CloudFormation you are deploying
* `ManagedAdAdminPassword` - Password of the AD admin user
* `ManagedAdAdminUsername` - Username of the AD admin user (e.g. <NetBIOS-name>\Admin)
* `ManagedAdUsersOU` - Organizational unit within AD to sync the Entra ID users to. Suggest to use the same users OU when installing RES so that RES can sync all the users automatically.
* `SenderEmail` - Sender email address for sending password to AD users
* `ManagedAdUserGroup` - ManagedAdUserGroup - All the synced users will be added to the specified AD group automatically. Default value is `res`. You can login the directory administration instance and add users to any other AD groups manually after the sync.
* `WindowsManagementHostInstanceId` - EC2 instance ID of the directory administration instance

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

The cost varies depending on the number of Entra ID users and frequency of the synchronization. All the Entra ID users will be synced to an AWS Managed AD eventually, so it will incur the cost of that resource as well.