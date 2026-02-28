<#
.SYNOPSIS
    Lists all Agent Identities in Microsoft Entra ID.

.DESCRIPTION
    Retrieves all Agent Identities from the Microsoft Graph beta endpoint
    and displays them as formatted JSON output. Requires an active Microsoft
    Graph session (Connect-MgGraph).

.EXAMPLE
    ./ListAgentIdentities.ps1

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

ConnectMgGraphIdentityScopes -TenantId $tenant_id

# Retrieve all Agent Identities and display as formatted JSON.
$params = @{
    Method     = "GET"
    Uri        = "https://graph.microsoft.com/beta/serviceprincipals/graph.agentIdentity"
    OutputType = "Json"
}
(Invoke-MgGraphRequest @params) |
    ConvertFrom-Json |
    ConvertTo-Json -Depth 10