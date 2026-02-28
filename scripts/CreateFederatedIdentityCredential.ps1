<#
.SYNOPSIS
    Creates or updates a federated identity credential on an agent blueprint.

.DESCRIPTION
    This script creates a federated identity credential on an agent blueprint in
    Azure Entra ID using the Microsoft Graph beta API. If a credential with the same
    name already exists and has a different subject, it prompts to update. Parameters
    can be passed directly or set as session variables.

.PARAMETER blueprint_app_id
    The app ID of the agent blueprint to associate the credential with.

.PARAMETER subject
    The subject claim for the federated identity credential
    For Managed Identities, this is typically the Principal ID (Object ID).
    For GitHub Actions, this follows the format: repo:<org>/<repo>:ref:refs/heads/<branch>

.PARAMETER issuer
    The issuer URL of the external identity provider.
    For Azure AD Managed Identity: https://login.microsoftonline.com/<tenant-id>/v2.0
    For GitHub Actions: https://token.actions.githubusercontent.com

.PARAMETER audiences
    The audience for the token. Defaults to "api://AzureADTokenExchange".

.PARAMETER description
    An optional description for the federated identity credential.

.PARAMETER fed_cred_name
    The name for the federated identity credential.

.EXAMPLE
    .\CreateFederatedIdentityCredential.ps1 -blueprint_app_id "00000000-..." -subject "4a37c1cb-46d0-4f0d-80ad-42ac331bc6ba" -issuer "https://login.microsoftonline.com/aff8623b-8223-419b-b6fd-f3f7013054ab/v2.0" -fed_cred_name "sample-fic"

.NOTES
    Requires the Microsoft.Graph PowerShell module with
    AgentIdentityBlueprint.AddRemoveCreds.All and Application.ReadWrite.All permissions.
    Returns a PSCustomObject with fed_cred_id, fed_cred_name, blueprint_app_id,
    subject, issuer, and audiences.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$blueprint_app_id = $blueprint_app_id,
    [string]$subject = $subject,
    [string]$issuer = $issuer,
    [string[]]$audiences = $(if ($audiences) { $audiences } else { @("api://AzureADTokenExchange") }),
    [string]$description = $(if ($description) { $description } else { "" }),
    [string]$fed_cred_name = $fed_cred_name
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Validate that required variables are set (either passed or pre-set in session).
if (-not $blueprint_app_id) {
    Write-Error "Error: `$blueprint_app_id is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $subject) {
    Write-Error "Error: `$subject is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $fed_cred_name) {
    Write-Error "Error: `$fed_cred_name is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $issuer) {
    Write-Error "Error: `$issuer is not set. Pass it as a parameter or set it in your session."
    return
}

. ./ConnectMgGraph.ps1

ConnectMgGraphCredScopes -TenantId $tenant_id

# Step 2: Verify Blueprint exists
try {
    $uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id"
    $blueprint = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
    Write-Host "Found Blueprint: $($blueprint.displayName)"
} catch {
    Write-Host "   ❌ Failed to find Blueprint: $($_.Exception.Message)" -ForegroundColor Red
    throw "Blueprint with App ID '$blueprint_app_id' not found"
}

# Check for existing federated credentials

$existingFic = $null
try {
    $uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id/federatedIdentityCredentials"
    $existingFics = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop).value
    
    if ($existingFics -and $existingFics.Count -gt 0) {
        Write-Host "Found $($existingFics.Count) existing credential(s):"
        foreach ($fic in $existingFics) {
            Write-Host "  - $($fic.name) (Subject: $($fic.subject))"
        }
        $existingFic = $existingFics | Where-Object { $_.name -eq $fed_cred_name }
    } else {
        Write-Host "No existing federated credentials found"
    }
} catch {
    Write-Host "Could not check for existing federated credentials: $($_.Exception.Message)"
}

# Create or update Federated Identity Credential

$credentialId = $null

if ($existingFic) {
    Write-Host "Federated Identity Credential '$fed_cred_name' already exists"
    Write-Host "Credential ID: $($existingFic.id)"
    Write-Host "Current Subject: $($existingFic.subject)"
    
    if ($existingFic.subject -ne $subject) {
        $update = Read-Host "Do you want to update the credential? (y/N)"
        if ($update -eq 'y' -or $update -eq 'Y') {
            try {
                $uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id/federatedIdentityCredentials/$($existingFic.id)"
                $body = @{
                    subject     = $subject
                    issuer      = $issuer
                    audiences   = $audiences
                    description = $description
                } | ConvertTo-Json -Depth 10
                
                Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body $body -ContentType "application/json" -ErrorAction Stop
                Write-Host "Federated Identity Credential updated!"
            } catch {
                Write-Host "   ❌ Failed to update: $($_.Exception.Message)" -ForegroundColor Red
                throw
            }
        }
    }
    $credentialId = $existingFic.id
} else {
    try {
        # Create using Graph API directly (beta endpoint required for Blueprints)
        $uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id/federatedIdentityCredentials"
        
        $body = @{
            name        = $fed_cred_name
            issuer      = $issuer
            subject     = $subject
            audiences   = $audiences
            description = $description
        } | ConvertTo-Json -Depth 10

        $ficResult = Invoke-MgGraphRequest -Method POST -Uri $uri -Body $body -ContentType "application/json" -ErrorAction Stop
        
        Write-Host "Federated Identity Credential created!"
        $credentialId = $ficResult.id
        Write-Host "Credential ID: $credentialId"
    } catch {
        Write-Host "   ❌ Failed to create Federated Identity Credential: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "   Troubleshooting:" -ForegroundColor Yellow
        Write-Host "   1. Ensure you have AgentIdentityBlueprint.AddRemoveCreds.All permission" -ForegroundColor Gray
        Write-Host "   2. Verify the Blueprint App ID is correct" -ForegroundColor Gray
        Write-Host "   3. Check that the subject format is valid for your scenario" -ForegroundColor Gray
        throw
    }
}

$result = [PSCustomObject]@{
    fed_cred_id      = $credentialId
    fed_cred_name    = $fed_cred_name
    blueprint_app_id = $blueprint_app_id
    subject          = $subject
    issuer           = $issuer
    audiences        = $audiences
}

return $result
