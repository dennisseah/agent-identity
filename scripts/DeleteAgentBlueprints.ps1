<#
.SYNOPSIS
    Deletes Agent Identity Blueprints by display name from Microsoft Entra ID.

.DESCRIPTION
    Retrieves all Agent Identity Blueprints from the Microsoft Graph beta
    endpoint, filters them by the specified display name, and deletes all
    matching entries. Requires an active Microsoft Graph session
    (Connect-MgGraph).

.PARAMETER blueprint_name
    The display name of the Agent Identity Blueprint to delete. All blueprints
    matching this name will be removed. If not passed, falls back to a session
    variable of the same name.

.EXAMPLE
    ./DeleteAgentBlueprints.ps1 -blueprint_name "MyBlueprint"

.EXAMPLE
    $blueprint_name = "MyBlueprint"
    ./DeleteAgentBlueprints.ps1

.NOTES
    Requires the Microsoft Graph PowerShell SDK with an active session.
    Deletes ALL blueprints matching the given name.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$tenant_id = $tenant_id,
    [string]$blueprint_name = $blueprint_name
)

if (-not $tenant_id) {
    Write-Error "Error: `$tenant_id is not set. Pass it as a parameter or set it in your session."
    return
}

if (-not $blueprint_name) {
    Write-Error "Error: `$blueprint_name is not set. Pass it as a parameter or set it in your session."
    return
}

. ./ConnectMgGraph.ps1

ConnectMgGraphBlueprintScopes -TenantId $tenant_id

# Retrieve all Agent Identity Blueprints from the Microsoft Graph beta endpoint.
$listParams = @{
    Method     = "GET"
    Uri        = "https://graph.microsoft.com/beta/applications/microsoft.graph.agentIdentityBlueprint"
    OutputType = "Json"
}
$blueprints = (Invoke-MgGraphRequest @listParams) | ConvertFrom-Json

# Filter blueprints matching the specified display name.
$matching = $blueprints.value | Where-Object { $_.displayName -eq $blueprint_name }

# Delete each matching blueprint.
foreach ($blueprint in $matching) {
    Write-Host "Deleting blueprint: $($blueprint.displayName) ($($blueprint.id))"
    $deleteParams = @{
        Method = "DELETE"
        Uri    = "https://graph.microsoft.com/beta/applications/microsoft.graph.agentIdentityBlueprint/$($blueprint.id)"
    }
    Invoke-MgGraphRequest @deleteParams
}
