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

# Retrieve all Agent Identities and display as formatted JSON.
$params = @{
    Method     = "GET"
    Uri        = "https://graph.microsoft.com/beta/serviceprincipals/graph.agentIdentity"
    OutputType = "Json"
}
(Invoke-MgGraphRequest @params) |
    ConvertFrom-Json |
    ConvertTo-Json -Depth 10