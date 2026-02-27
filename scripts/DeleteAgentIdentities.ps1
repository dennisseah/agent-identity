<#
.SYNOPSIS
    Deletes Agent Identities by display name from Microsoft Entra ID.

.DESCRIPTION
    Retrieves all Agent Identities from the Microsoft Graph beta endpoint,
    filters them by the specified display name, and deletes all matching
    entries. Requires an active Microsoft Graph session (Connect-MgGraph).

.PARAMETER agent_id_name
    The display name of the Agent Identity to delete. All identities matching
    this name will be removed. If not passed, falls back to a session variable
    of the same name.

.EXAMPLE
    ./DeleteAgentIdentities.ps1 -agent_id_name "MyAgentIdentity"

.EXAMPLE
    $agent_id_name = "MyAgentIdentity"
    ./DeleteAgentIdentities.ps1

.NOTES
    Requires the Microsoft Graph PowerShell SDK with an active session.
    Deletes ALL identities matching the given name.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$agent_id_name = $agent_id_name
)

if (-not $agent_id_name) {
    Write-Error "Error: `$agent_id_name is not set. Pass it as a parameter or set it in your session."
    return
}

# Retrieve all Agent Identities from the Microsoft Graph beta endpoint.
$listResponse = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/servicePrincipals/graph.agentIdentity" `
    -ErrorAction Stop

# Filter blueprints matching the specified display name.
$matching = $listResponse.value | Where-Object { $_.displayName -eq $agent_id_name }

# Delete each matching blueprint.
foreach ($identity in $matching) {
    Write-Host "Deleting identity: $($identity.displayName) ($($identity.id))"
    $deleteParams = @{
        Method = "DELETE"
        Uri    = "https://graph.microsoft.com/beta/servicePrincipals/graph.agentIdentity/$($identity.id)"
    }
    Invoke-MgGraphRequest @deleteParams
}
