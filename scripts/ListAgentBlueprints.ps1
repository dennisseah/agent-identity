<#
.SYNOPSIS
    Lists all Agent Identity Blueprints in Microsoft Entra ID.

.DESCRIPTION
    Retrieves all Agent Identity Blueprints from the Microsoft Graph beta
    endpoint and displays them as formatted JSON output. Requires an active
    Microsoft Graph session (Connect-MgGraph).

.EXAMPLE
    ./ListAgentBlueprints.ps1

.NOTES
    Requires the Microsoft Graph PowerShell SDK with an active session.
#>

# Retrieve all Agent Identity Blueprints and display as formatted JSON.
$params = @{
    Method     = "GET"
    Uri        = "https://graph.microsoft.com/beta/applications/microsoft.graph.agentIdentityBlueprint"
    OutputType = "Json"
}
(Invoke-MgGraphRequest @params) | ConvertFrom-Json | ConvertTo-Json -Depth 10