<#
.SYNOPSIS
    Creates a user-assigned managed identity in the specified resource group.

.DESCRIPTION
    This script creates a user-assigned managed identity in Azure. It first verifies
    that the current user has the required role assignment (Managed Identity Contributor,
    Contributor, or Owner) on the target resource group. If a managed identity with the
    same name already exists, it returns the existing identity. Parameters can be passed
    directly or set as session variables.

.PARAMETER subscription_id
    The Azure subscription ID containing the target resource group.

.PARAMETER mi_name
    The name for the new user-assigned managed identity.

.PARAMETER rg_name
    The name of the resource group in which the managed identity will be created.

.PARAMETER location
    The Azure region for the managed identity. Defaults to "eastus2".

.EXAMPLE
    .\CreateUserManagedIdentity.ps1 -subscription_id "e900f8d6-..." -mi_name "denz_mi" -rg_name "rg_dennisseah"

.EXAMPLE
    .\CreateUserManagedIdentity.ps1 -subscription_id "e900f8d6-..." -mi_name "denz_mi" -rg_name "rg_dennisseah" -location "westus2"

.NOTES
    Requires the Az.ManagedServiceIdentity and Az.Resources modules.
    Returns a PSCustomObject with ManagedIdentityName, principal_id, client_id,
    resource_id, resource_id, and location.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$subscription_id = $subscription_id,
    [string]$mi_name = $mi_name,
    [string]$rg_name = $rg_name,
    [string]$location = $(if ($location) { $location } else { "eastus2" })
)

# Validate that required variables are set (either passed or pre-set in session).
if (-not $subscription_id) {
    Write-Error "Error: `$subscription_id is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $mi_name) {
    Write-Error "Error: `$mi_name (managed_identity_name) is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $rg_name) {
    Write-Error "Error: `$rg_name is not set. Pass it as a parameter or set it in your session."
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Verify the current user has the Managed Identity Contributor role on the resource group.
$currentUser = (Get-AzADUser -SignedIn).Id
$scope = "/subscriptions/$subscription_id/resourceGroups/$rg_name"
$roleAssignment = Get-AzRoleAssignment -ObjectId $currentUser -Scope $scope |
    Where-Object {
        $_.RoleDefinitionName -eq "Managed Identity Contributor" -or
        $_.RoleDefinitionName -eq "Contributor" -or
        $_.RoleDefinitionName -eq "Owner"
    }

if (-not $roleAssignment) {
    Write-Error "Your account does not have 'Managed Identity Contributor' role on resource group '$rg_name'."
    return
}

Write-Host "Role check passed: $($roleAssignment[0].RoleDefinitionName) on $scope" -ForegroundColor Green

$existingMi = Get-AzUserAssignedIdentity -ResourceGroupName $rg_name -Name $mi_name -ErrorAction SilentlyContinue


if ($existingMi) {
    Write-Host "Managed Identity already exists"
    $managedIdentity = $existingMi
} else {
    $managedIdentity = New-AzUserAssignedIdentity `
        -Name $mi_name `
        -ResourceGroupName $rg_name `
        -Location $location `
        -ErrorAction Stop

    Write-Host "Managed Identity created!"
}

$msiPrincipalId = $managedIdentity.PrincipalId
$msiClientId = $managedIdentity.ClientId

$result = [PSCustomObject]@{
    ManagedIdentityName = $mi_name
    principal_id        = $msiPrincipalId
    client_id           = $msiClientId
    resource_id         = $managedIdentity.Id
    resource_id         = $rg_name
    location            = $location
}

return $result