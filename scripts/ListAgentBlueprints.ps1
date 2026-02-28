<#
.SYNOPSIS
    Lists all Agent Identity Blueprints in Microsoft Entra ID.

.DESCRIPTION
    Retrieves all Agent Identity Blueprints from the Microsoft Graph beta
    endpoint and displays them as formatted JSON output. Requires an active
    Microsoft Graph session (Connect-MgGraph).


.PARAMETER tenant_id
    The Azure tenant ID to authenticate against. If not passed, falls back to
    a session variable of the same name.

.EXAMPLE
    ./ListAgentBlueprints.ps1 -tenant_id "00000000-0000-0000-0000-000000000000"

.NOTES
    Requires the Microsoft Graph PowerShell SDK with an active session.
#>

param(
    [string]$tenant_id = $tenant_id
)

if (-not $tenant_id) {
    Write-Error "Error: `$tenant_id is not set. Pass it as a parameter or set it in your session."
    return
}

. ./ConnectMgGraph.ps1

ConnectMgGraphBlueprintScopes -TenantId $tenant_id

# Retrieve all Agent Identity Blueprints and display as formatted JSON.
$params = @{
    Method     = "GET"
    Uri        = "https://graph.microsoft.com/beta/applications/microsoft.graph.agentIdentityBlueprint"
    OutputType = "Json"
}
(Invoke-MgGraphRequest @params) | ConvertFrom-Json | ConvertTo-Json -Depth 10