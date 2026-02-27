<#
.SYNOPSIS
    Removes an OAuth2 permission scope from an agent blueprint.

.DESCRIPTION
    This script removes a specified OAuth2 permission scope from an agent blueprint
    in Azure Entra ID using the Microsoft Graph beta API. The scope is first disabled
    before removal, as required by the Graph API. If the scope does not exist on the
    blueprint, the script reports that and exits. Parameters can be passed directly or
    set as session variables.

.PARAMETER tenant_id
    The Azure tenant ID for authentication.

.PARAMETER blueprint_app_id
    The app ID of the agent blueprint to update.

.PARAMETER scope_id
    The ID of the OAuth2 permission scope to remove.

.EXAMPLE
    .\RemoveScope.ps1 -tenant_id "aff8623b-..." -blueprint_app_id "f064fe69-..." -scope_id "a1b2c3d4-..."

.NOTES
    Requires the Microsoft.Graph PowerShell module with
    AgentIdentityBlueprint.ReadWrite.All and Application.ReadWrite.All permissions.
#>

param(
    [string]$tenant_id = $tenant_id,
    [string]$blueprint_app_id = $blueprint_app_id,
    [string]$scope_id = $scope_id
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
if (-not $scope_id) {
    Write-Error "Error: `$scope_id is not set. Pass it as a parameter or set it in your session."
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredScopes = @(
    "AgentIdentityBlueprint.ReadWrite.All",
    "Application.ReadWrite.All"
)

# Authenticate to Microsoft Graph with the required scopes
Connect-MgGraph -Scopes $requiredScopes -TenantId $tenant_id -ErrorAction Stop -NoWelcome

# Retrieve the blueprint
$uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id"
$existingApp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

Write-Host "Blueprint: $($existingApp.displayName)"

# Check existing scopes
$existingScopes = $existingApp.api.oauth2PermissionScopes
if (-not $existingScopes -or $existingScopes.Count -eq 0) {
    Write-Host "No OAuth2 scopes configured on this blueprint."
    return
}

Write-Host "Current scopes:"
foreach ($s in $existingScopes) {
    Write-Host "  - $($s.value) (ID: $($s.id))"
}

$targetScope = $existingScopes | Where-Object { $_.id -eq $scope_id }
if (-not $targetScope) {
    Write-Host ""
    Write-Host "Scope with ID '$scope_id' not found on this blueprint. Nothing to remove."
    return
}

Write-Host ""
Write-Host "Removing scope: $($targetScope.value) (ID: $scope_id)"

# Step 1: Disable the scope first (Graph API requires this before removal)
Write-Host "Disabling scope before removal..."

$disabledScopes = @()
foreach ($s in $existingScopes) {
    $entry = @{
        id                      = $s.id
        adminConsentDescription = $s.adminConsentDescription
        adminConsentDisplayName = $s.adminConsentDisplayName
        isEnabled               = if ($s.id -eq $scope_id) { $false } else { $s.isEnabled }
        type                    = $s.type
        value                   = $s.value
        userConsentDescription  = $s.userConsentDescription
        userConsentDisplayName  = $s.userConsentDisplayName
    }
    $disabledScopes += $entry
}

$body = @{
    api = @{
        oauth2PermissionScopes = $disabledScopes
    }
} | ConvertTo-Json -Depth 10

try {
    Invoke-MgGraphRequest -Method PATCH `
        -Uri $uri `
        -Body $body `
        -ContentType "application/json" `
        -ErrorAction Stop
} catch {
    Write-Host "   ❌ Failed to disable scope: $($_.Exception.Message)" -ForegroundColor Red
    throw
}

# Step 2: Remove the disabled scope
Write-Host "Removing disabled scope..."

$remainingScopes = @()
foreach ($s in $existingScopes) {
    if ($s.id -ne $scope_id) {
        $remainingScopes += @{
            id                      = $s.id
            adminConsentDescription = $s.adminConsentDescription
            adminConsentDisplayName = $s.adminConsentDisplayName
            isEnabled               = $s.isEnabled
            type                    = $s.type
            value                   = $s.value
            userConsentDescription  = $s.userConsentDescription
            userConsentDisplayName  = $s.userConsentDisplayName
        }
    }
}

$body = @{
    api = @{
        oauth2PermissionScopes = $remainingScopes
    }
} | ConvertTo-Json -Depth 10

try {
    Invoke-MgGraphRequest -Method PATCH `
        -Uri $uri `
        -Body $body `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-Host "Scope removed successfully!"

    if ($remainingScopes.Count -gt 0) {
        Write-Host "Remaining scopes:"
        foreach ($s in $remainingScopes) {
            Write-Host "  - $($s.value) (ID: $($s.id))"
        }
    } else {
        Write-Host "No scopes remain on this blueprint."
    }
} catch {
    Write-Host "   ❌ Failed to remove scope: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Note: Agent Identity Blueprints require the beta API endpoint." -ForegroundColor Yellow
    throw
}
