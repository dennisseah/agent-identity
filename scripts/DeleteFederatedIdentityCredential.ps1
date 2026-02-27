<#
.SYNOPSIS
    Deletes a federated identity credential from a blueprint by subject.

.DESCRIPTION
    This script deletes a federated identity credential associated with an agent
    blueprint in Azure Entra ID. It looks up all federated identity credentials on
    the specified blueprint, filters by the given subject, and deletes each match.
    Parameters can be passed directly or set as session variables.

.PARAMETER blueprint_app_id
    The app ID of the agent blueprint containing the federated identity credential.

.PARAMETER subject
    The subject claim of the federated identity credential to delete.
    For Managed Identities, this is typically the Principal ID (Object ID).
    For GitHub Actions, this follows the format: repo:<org>/<repo>:ref:refs/heads/<branch>

.EXAMPLE
    .\DeleteFederatedIdentityCredential.ps1 -blueprint_app_id "00000000-..." -subject "system:serviceaccount:default:my-agent"

.NOTES
    Requires the Microsoft.Graph PowerShell module with
    AgentIdentityBlueprint.AddRemoveCreds.All and Application.ReadWrite.All permissions.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$blueprint_app_id = $blueprint_app_id,
    [string]$subject = $subject
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

$requiredScopes = @(
    "AgentIdentityBlueprint.AddRemoveCreds.All",
    "Application.ReadWrite.All"
)

# Authenticate to Microsoft Graph with the required scopes.
Connect-MgGraph -Scopes $requiredScopes -TenantId $tenant_id -ErrorAction Stop -NoWelcome

# Retrieve all federated identity credentials for the blueprint.
try {
    $uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id/federatedIdentityCredentials"
    $fics = (Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop).value
} catch {
    Write-Error "Failed to retrieve federated identity credentials: $($_.Exception.Message)"
    return
}

if (-not $fics -or $fics.Count -eq 0) {
    Write-Warning "No federated identity credentials found on blueprint '$blueprint_app_id'."
    return
}

# Filter by subject.
$matchingFics = $fics | Where-Object { $_.subject -eq $subject }

if (-not $matchingFics) {
    Write-Warning "No federated identity credential with subject '$subject' found on blueprint '$blueprint_app_id'."
    return
}

# Delete each matching credential.
foreach ($fic in $matchingFics) {
    try {
        $deleteUri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id/federatedIdentityCredentials/$($fic.id)"
        Invoke-MgGraphRequest -Method DELETE -Uri $deleteUri -ErrorAction Stop
        Write-Host "Deleted federated identity credential '$($fic.name)' (Subject: $($fic.subject))" -ForegroundColor Green
    } catch {
        Write-Host "Failed to delete credential '$($fic.name)': $($_.Exception.Message)" -ForegroundColor Red
    }
}
