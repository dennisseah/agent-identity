<#
.SYNOPSIS
    Lists the identifier URIs and OAuth2 permission scopes for an agent blueprint.

.DESCRIPTION
    This script retrieves and displays the identifier URIs and OAuth2 permission
    scopes configured on an agent blueprint in Azure Entra ID using the Microsoft
    Graph beta API. Parameters can be passed directly or set as session variables.

.PARAMETER tenant_id
    The Azure tenant ID for authentication.

.PARAMETER blueprint_app_id
    The app ID of the agent blueprint to query.

.EXAMPLE
    .\ListIdentifierURIandScopes.ps1 -tenant_id "aff8623b-..." -blueprint_app_id "f064fe69-..."

.NOTES
    Requires the Microsoft.Graph PowerShell module with
    AgentIdentityBlueprint.ReadWrite.All and Application.Read.All permissions.
    Returns a PSCustomObject with blueprint_app_id, IdentifierUris, and Scopes.
#>

param(
    [string]$tenant_id = $tenant_id,
    [string]$blueprint_app_id = $blueprint_app_id
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

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. ./ConnectMgGraph.ps1

ConnectMgGraphBlueprintWriteScopes -TenantId $tenant_id

try {
    $uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id"
    $app = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

    Write-Host "Blueprint: $($app.displayName)"
    Write-Host ""

    # Display identifier URIs
    if ($app.identifierUris -and $app.identifierUris.Count -gt 0) {
        Write-Host "Identifier URIs:"
        foreach ($u in $app.identifierUris) {
            Write-Host "  - $u"
        }
    } else {
        Write-Host "Identifier URIs: (none)"
    }

    Write-Host ""

    # Display OAuth2 permission scopes
    $scopes = $app.api.oauth2PermissionScopes
    if ($scopes -and $scopes.Count -gt 0) {
        Write-Host "OAuth2 Scopes: $($scopes.Count)"
        foreach ($s in $scopes) {
            Write-Host "  - $($s.value) ($($s.adminConsentDisplayName))"
            Write-Host "    ID:          $($s.id)"
            Write-Host "    Type:        $($s.type)"
            Write-Host "    Enabled:     $($s.isEnabled)"
            Write-Host "    Description: $($s.adminConsentDescription)"
        }
    } else {
        Write-Host "OAuth2 Scopes: (none)"
    }
} catch {
    Write-Host "   ❌ Failed to retrieve Blueprint: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

$result = [PSCustomObject]@{
    blueprint_app_id = $blueprint_app_id
    IdentifierUris   = $app.identifierUris
    Scopes           = $app.api.oauth2PermissionScopes
}

return $result
