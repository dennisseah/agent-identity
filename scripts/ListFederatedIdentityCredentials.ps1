<#
.SYNOPSIS
    Lists all federated identity credentials for a specified agent blueprint.

.DESCRIPTION
    This script retrieves and displays all federated identity credentials associated
    with an agent blueprint in Azure Entra ID. The output is formatted as JSON for
    readability. Parameters can be passed directly or set as session variables.

.PARAMETER blueprint_app_id
    The app ID of the agent blueprint to list federated identity credentials for.

.EXAMPLE
    .\ListFederatedIdentityCredentials.ps1 -blueprint_app_id "00000000-..."

.NOTES
    Requires the Microsoft.Graph PowerShell module with Application.Read.All
    or Application.ReadWrite.All permissions.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$blueprint_app_id = $blueprint_app_id
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Validate that required variables are set (either passed or pre-set in session).
if (-not $blueprint_app_id) {
    Write-Error "Error: `$blueprint_app_id is not set. Pass it as a parameter or set it in your session."
    return
}

$requiredScopes = @(
    "Application.Read.All"
)

# Authenticate to Microsoft Graph with the required scopes.
Connect-MgGraph -Scopes $requiredScopes -TenantId $tenant_id -ErrorAction Stop -NoWelcome

# Retrieve federated identity credentials for the blueprint.
$splatParams = @{
    Method      = "GET"
    Uri         = "https://graph.microsoft.com/beta/applications/$blueprint_app_id/federatedIdentityCredentials"
    ErrorAction = "Stop"
}

$response = Invoke-MgGraphRequest @splatParams
$response.value | ConvertTo-Json -Depth 10
