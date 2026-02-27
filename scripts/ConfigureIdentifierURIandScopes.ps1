<#
.SYNOPSIS
    Configures the identifier URI and an OAuth2 permission scope on an agent blueprint.

.DESCRIPTION
    This script sets the identifier URI and adds or updates an OAuth2 permission
    scope on an agent blueprint in Azure Entra ID using the Microsoft Graph beta
    API. If a scope with the same name already exists, it is updated in place.
    Parameters can be passed directly or set as session variables.

.PARAMETER tenant_id
    The Azure tenant ID for authentication.

.PARAMETER blueprint_app_id
    The app ID of the agent blueprint to configure.

.PARAMETER identifier_uri
    The identifier URI to set on the blueprint. Defaults to "api://<blueprint_app_id>"
    when not provided.

.PARAMETER scope_name
    The name of the OAuth2 permission scope (e.g., "read.all").

.PARAMETER scope_desc
    A description for the scope, used for admin and user consent.

.PARAMETER scope_display_name
    The display name for the scope, shown during consent prompts.

.PARAMETER scope_type
    The type of the scope. Valid values are "User" and "Admin". Defaults to "User".

.EXAMPLE
    .\ConfigureIdentifierURIandScopes.ps1 -tenant_id "aff8623b-..." -blueprint_app_id "f064fe69-..." -scope_name "read.all" -scope_desc "Read all data" -scope_display_name "Read All"

.NOTES
    Requires the Microsoft.Graph PowerShell module with
    AgentIdentityBlueprint.ReadWrite.All and Application.ReadWrite.All permissions.
    Returns a PSCustomObject with blueprint_app_id, identifier_uri, scope_name,
    scopeId, scope_type, and tenant_id.
#>

param(
    [string]$tenant_id = $tenant_id,
    [string]$blueprint_app_id = $blueprint_app_id,
    [string]$identifier_uri = $identifier_uri,
    [string]$scope_name = $scope_name,
    [string]$scope_desc = $scope_desc,
    [string]$scope_display_name = $scope_display_name,
    [ValidateSet("User", "Admin")]
    [string]$scope_type = $(if ($scope_type) { $scope_type } else { "User" })
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
if (-not $identifier_uri) {
    $identifier_uri = "api://$blueprint_app_id"
}
if (-not $scope_name) {
    Write-Error "Error: `$scope_name is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $scope_desc) {
    Write-Error "Error: `$scope_desc is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $scope_display_name) {
    Write-Error "Error: `$scope_display_name is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $scope_type) {
    Write-Error "Error: `$scope_type is not set. Pass it as a parameter or set it in your session."
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredScopes = @(
    "AgentIdentityBlueprint.ReadWrite.All",
    "Application.ReadWrite.All"
)

# Authenticate to Microsoft Graph with the required scopes for managing
Connect-MgGraph -Scopes $requiredScopes -TenantId $tenant_id -ErrorAction Stop -NoWelcome

# get the blueprint to update
$uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id"
$existingApp = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop

# Display existing identifier URIs and scopes for the blueprint
if ($existingApp.identifierUris -and $existingApp.identifierUris.Count -gt 0) {
    Write-Host "Existing Identifier URIs: $($existingApp.identifierUris -join ', ')"
}

$existingScopes = $existingApp.api.oauth2PermissionScopes
if ($existingScopes -and $existingScopes.Count -gt 0) {
    Write-Host "Existing scopes: $($existingScopes.Count)"
    foreach ($s in $existingScopes) {
        Write-Host "  - $($s.value) (ID: $($s.id))"
    }
}

# Check if scope already exists

$existingScope = $existingScopes | Where-Object { $_.value -eq $scope_name }
$scopeId = if ($existingScope) { $existingScope.id } else { [guid]::NewGuid().ToString() }

if ($existingScope) {
    Write-Host "Scope '$scope_name' already exists with ID: $scopeId"
    Write-Host "Will update existing scope configuration"
} else {
    Write-Host "Creating new scope '$scope_name' with ID: $scopeId"
}

$newScope = @{
    id                      = $scopeId
    adminConsentDescription = $scope_desc
    adminConsentDisplayName = $scope_display_name
    isEnabled               = $true
    type                    = $scope_type
    value                   = $scope_name
    userConsentDescription  = $scope_desc
    userConsentDisplayName  = $scope_display_name
}

# Merge with existing scopes (replace if same name, add if new)
$allScopes = @()
$scopeUpdated = $false

if ($existingScopes) {
    foreach ($s in $existingScopes) {
        if ($s.value -eq $scope_name) {
            $allScopes += $newScope
            $scopeUpdated = $true
        } else {
            # Keep existing scope as hashtable
            $allScopes += @{
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
}

if (-not $scopeUpdated) {
    $allScopes += $newScope
}

Write-Host "Total scopes to configure: $($allScopes.Count)"

# Update the Blueprint
Write-Host "4️⃣" "Updating Blueprint configuration..."

# Build the request body
# Note: Must use beta API - v1.0 doesn't support Agent Identity Blueprints
$body = @{
    identifierUris = @($identifier_uri)
    api            = @{
        oauth2PermissionScopes = $allScopes
    }
} | ConvertTo-Json -Depth 10


# Step 4: Update the Blueprint
Write-Host "Updating Blueprint configuration..."

# Build the request body
# Note: Must use beta API - v1.0 doesn't support Agent Identity Blueprints
$body = @{
    identifierUris = @($identifier_uri)
    api            = @{
        oauth2PermissionScopes = $allScopes
    }
} | ConvertTo-Json -Depth 10

try {
    $uri = "https://graph.microsoft.com/beta/applications/$blueprint_app_id"
    
    Invoke-MgGraphRequest -Method PATCH `
        -Uri $uri `
        -Body $body `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-Host "Blueprint updated successfully!"
} catch {
    Write-Host "   ❌ Failed to update Blueprint: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Note: Agent Identity Blueprints require the beta API endpoint." -ForegroundColor Yellow
    Write-Host "   The standard Update-MgApplication cmdlet uses v1.0 and will fail." -ForegroundColor Yellow
    throw
}

# Create result object for pipeline use
$result = [PSCustomObject]@{
    blueprint_app_id = $blueprint_app_id
    identifier_uri   = $identifier_uri
    scope_name       = $scope_name
    scope_id         = $scopeId
    scope_type       = $scope_type
    tenant_id        = $tenant_id
}

return $result

