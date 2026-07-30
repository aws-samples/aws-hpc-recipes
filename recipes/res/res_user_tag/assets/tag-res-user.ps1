# tag-res-user.ps1 - Adds a res:User cost-allocation tag (the RES session owner)
# to the desktop instance it runs on. Registered on a project's
# scripts.windows.on_vdi_configured event. Runs as SYSTEM/Administrator after RES
# configures the VDI.
#
# Fails safe: always exits 0 (would not fail the desktop over a billing tag).

$ErrorActionPreference = "Continue"
$TagKey      = "res:User"
$ProfileName = "bootstrap_profile"

function Write-Log { param([string]$Message) Write-Output "[tag-res-user] $Message" }

# Resolve owner: IDEA_SESSION_OWNER, then SESSION_OWNER, then OWNER_ID.
$Owner = $env:IDEA_SESSION_OWNER
if ([string]::IsNullOrEmpty($Owner)) { $Owner = $env:SESSION_OWNER }
if ([string]::IsNullOrEmpty($Owner)) { $Owner = $env:OWNER_ID }
if ([string]::IsNullOrEmpty($Owner)) {
    Write-Log "WARN: could not determine session owner; skipping res:User tag."
    exit 0
}

# IMDSv2: token, then instance-id and region.
try {
    $Token = Invoke-RestMethod -Method PUT -Uri "http://169.254.169.254/latest/api/token" `
        -Headers @{ "X-aws-ec2-metadata-token-ttl-seconds" = "300" }
    $Headers = @{ "X-aws-ec2-metadata-token" = $Token }
    $InstanceId = Invoke-RestMethod -Method GET -Headers $Headers `
        -Uri "http://169.254.169.254/latest/meta-data/instance-id"
    $Doc = Invoke-RestMethod -Method GET -Headers $Headers `
        -Uri "http://169.254.169.254/latest/dynamic/instance-identity/document"
    $Region = $Doc.region
} catch {
    Write-Log "WARN: could not resolve instance metadata from IMDS; skipping res:User tag. $_"
    exit 0
}
if ([string]::IsNullOrEmpty($InstanceId) -or [string]::IsNullOrEmpty($Region)) {
    Write-Log "WARN: empty instance-id/region from IMDS; skipping res:User tag."
    exit 0
}

# Apply the tag using broker credentials (bootstrap_profile). Idempotent.
& aws ec2 create-tags `
    --profile $ProfileName `
    --region $Region `
    --resources $InstanceId `
    --tags "Key=$TagKey,Value=$Owner"
if ($LASTEXITCODE -eq 0) {
    Write-Log "Applied $TagKey=$Owner to $InstanceId in $Region."
} else {
    Write-Log "WARN: create-tags failed (exit $LASTEXITCODE) for $InstanceId; continuing."
}
exit 0
