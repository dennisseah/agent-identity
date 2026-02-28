<#
.SYNOPSIS
    Removes an identifier URI from an agent blueprint.

.DESCRIPTION
    This script removes a specified identifier URI from an agent blueprint in
    Azure Entra ID using the Microsoft Graph beta API. If the URI does not exist
    on the blueprint, the script reports that and exits. Parameters can be passed
    directly or set as session variables.

.PARAMETER tenant_id
    The Azure tenant ID for authentication.

.PARAMETER blueprint_app_id
    The app ID of the agent blueprint to update.

.PARAMETER identifier_uri
    The identifier URI to remove from the blueprint.

.EXAMPLE
    .\RemoveIdentifierURI.ps1 -tenant_id "aff8623b-..." -blueprint_app_id "f064fe69-..." -identifier_uri "api://f064fe69-..."

.NOTES
    Requires the Microsoft.Graph PowerShell module with
    AgentIdentityBlueprint.ReadWrite.All and Application.ReadWrite.All permissions.
#>

param(
    [string]$tenant_id = $tenant_id,
    [string]$blueprint_app_id = $blueprint_app_id,
    [string]$identifier_uri = $identifier_uri
)

# Validate that required variables are set (either passed or pre-set in session).
if (-not $tenant_id) {
    Write-Error "Error: `$tenant_id is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $blueprint_app_id) {
    Write-Error "Error: `$blueprint_app_id is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $identifier_uri) {
    Write-Error "Error: `$identifier_uri is not set. Pass it as a parameter or set it in your session."
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. ./ConnectMgGraph.ps1

ConnectMgGraphBlueprintWriteScopes -TenantId $tenant_id

# Retrieve the blueprint
$uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id"
$existingApp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

Write-Host "Blueprint: $($existingApp.displayName)"

# Check if the identifier URI exists
$currentUris = $existingApp.identifierUris
if (-not $currentUris -or $currentUris.Count -eq 0) {
    Write-Host "No identifier URIs configured on this blueprint."
    return
}

Write-Host "Current Identifier URIs:"
foreach ($u in $currentUris) {
    Write-Host "  - $u"
}

if ($identifier_uri -notin $currentUris) {
    Write-Host ""
    Write-Host "Identifier URI '$identifier_uri' not found on this blueprint. Nothing to remove."
    return
}

# Remove the specified URI
$updatedUris = @($currentUris | Where-Object { $_ -ne $identifier_uri })

Write-Host ""
Write-Host "Removing identifier URI: $identifier_uri"

# Build the request body
$body = @{
    identifierUris = $updatedUris
} | ConvertTo-Json -Depth 10

try {
    Invoke-MgGraphRequest -Method PATCH `
        -Uri $uri `
        -Body $body `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-Host "Identifier URI removed successfully!"

    if ($updatedUris.Count -gt 0) {
        Write-Host "Remaining Identifier URIs:"
        foreach ($u in $updatedUris) {
            Write-Host "  - $u"
        }
    } else {
        Write-Host "No identifier URIs remain on this blueprint."
    }
} catch {
    Write-Host "   ❌ Failed to update Blueprint: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Note: Agent Identity Blueprints require the beta API endpoint." -ForegroundColor Yellow
    throw
}
