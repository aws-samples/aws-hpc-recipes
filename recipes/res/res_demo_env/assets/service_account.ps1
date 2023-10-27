Import-Module -Name ActiveDirectory

$service_account_name = "${ServiceAccount}"
$computers_ou = "OU=Users,OU=${OU},DC=${DC}"
$users_ou = "OU=Users,OU=${OU},DC=${DC}"
$computer_write_group = "RES Service Account"

echo "Running script to add service account to write computers"

# Enter the Active Directory PowerShell
cd ad:

# Create Group for Managing Computers
try {
     New-ADGroup -Name "$computer_write_group" -GroupCategory Security -GroupScope Global -DisplayName "$computer_write_group" -Description "Members of this group are service accounts"
}
catch [Microsoft.ActiveDirectory.Management.ADException]{
    Switch ($_.Exception.Message){
        "already in use" {Write-Host "Group has already been created."}
        default{Write-Host "Unhandled ADException: $_"}
    }
}


try {
    # Add Service Account to Group that will have permission to write computers
    Add-ADGroupMember -Identity "CN=$computer_write_group,$computers_ou" -Members "$service_account_name"

    # Look up SID and acl for Computers OU
    $computers = Get-ADOrganizationalUnit -Identity "$computers_ou"
    $group = Get-ADGroup -Identity "CN=$computer_write_group,$users_ou"
    $sid = new-object System.Security.Principal.SecurityIdentifier $group.SID
    $acl = get-acl $computers

    # Allow writes to computers
    $computers_schema_id = new-object Guid bf967a86-0de6-11d0-a285-00aa003049e2
    $ace = new-object System.DirectoryServices.ActiveDirectoryAccessRule $sid,"CreateChild","Allow",$computers_schema_id
    $acl.AddAccessRule($ace)
    Set-Acl -AclObject $acl -Path "$computers_ou"
    echo "Success."
}
catch {
    Write-Host "Failed to add SystemAccount to delegate computers."
}
