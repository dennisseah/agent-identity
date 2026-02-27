<#
.SYNOPSIS
    Deletes a user-assigned managed identity by name from a specified resource group.

.DESCRIPTION
    This script deletes a user-assigned managed identity in Azure. It checks whether
    the identity exists before attempting deletion. Parameters can be passed directly
    or set as session variables.

.PARAMETER rg_name
    The name of the resource group containing the managed identity.

.PARAMETER mi_name
    The display name of the user-assigned managed identity to delete.

.EXAMPLE
    .\DeleteUserManagedIdentity.ps1 -rg_name "rg_dennisseah" -mi_name "denz_mi"

.NOTES
    Requires the Az.ManagedServiceIdentity module and appropriate permissions
    (Managed Identity Contributor, Contributor, or Owner) on the resource group.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$rg_name = $rg_name,
    [string]$mi_name = $mi_name
)

# Validate that required variables are set (either passed or pre-set in session).
if (-not $rg_name) {
    Write-Error "Error: `$rg_name is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $mi_name) {
    Write-Error "Error: `$mi_name is not set. Pass it as a parameter or set it in your session."
    return
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Check if the managed identity exists.
$existingMi = Get-AzUserAssignedIdentity -ResourceGroupName $rg_name -Name $mi_name -ErrorAction SilentlyContinue

if (-not $existingMi) {
    Write-Warning "Managed identity '$mi_name' does not exist in resource group '$rg_name'. Nothing to delete."
    return
}

# Delete the managed identity.
try {
    Remove-AzUserAssignedIdentity -ResourceGroupName $rg_name -Name $mi_name -ErrorAction Stop
    Write-Host "Successfully deleted managed identity '$mi_name' from resource group '$rg_name'." -ForegroundColor Green
} catch {
    Write-Error "Failed to delete managed identity '$mi_name'. Error: $($_.Exception.Message)"
}
