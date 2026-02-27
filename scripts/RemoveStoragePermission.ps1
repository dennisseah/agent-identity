<#
.SYNOPSIS
    Removes the "Storage Blob Data Reader" role assignment from an Agent Identity
    on a specified Azure Storage Account.

.PARAMETER storage_acc_name
    The name of the Azure Storage Account. Falls back to the session variable if not provided.

.PARAMETER rg_name
    The name of the Resource Group containing the Storage Account. Falls back to the session variable if not provided.

.PARAMETER agent_id_id
    The Application (client) ID of the Agent Identity. Falls back to the session variable if not provided.
#>
param(
    [string]$storage_acc_name = $storage_acc_name,
    [string]$rg_name = $rg_name,
    [string]$agent_id_id = $agent_id_id
)

if (-not $storage_acc_name) {
    Write-Error "Error: `$storage_acc_name is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $rg_name) {
    Write-Error "Error: `$rg_name is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $agent_id_id) {
    Write-Error "Error: `$agent_id_id is not set. Pass it as a parameter or set it in your session."
    return
}

# Validate that the storage account exists and retrieve its details.
$storageAccount = Get-AzStorageAccount -ResourceGroupName $rg_name -Name $storage_acc_name -ErrorAction SilentlyContinue
if (-not $storageAccount) {
    Write-Host "❌ Storage account '$storage_acc_name' not found in resource group '$rg_name'" -ForegroundColor Red
    exit 1
}
Write-Host "Storage account '$storage_acc_name' found in resource group '$rg_name'." -ForegroundColor Green

# Check if the role assignment exists
Write-Host "`nChecking 'Storage Blob Data Reader' role assignment for Agent Identity..." -ForegroundColor Yellow

$roleAssignment = az role assignment list `
    --assignee $agent_id_id `
    --role "Storage Blob Data Reader" `
    --scope $storageAccount.Id `
    --only-show-errors 2>$null | ConvertFrom-Json

if (-not $roleAssignment -or $roleAssignment.Count -eq 0) {
    Write-Host "   ⚠️ No 'Storage Blob Data Reader' role assignment found for this Agent Identity." -ForegroundColor Yellow
    return
}

# Remove the role assignment
Write-Host "Removing 'Storage Blob Data Reader' role from Agent Identity..." -ForegroundColor Yellow

try {
    az role assignment delete `
        --assignee $agent_id_id `
        --role "Storage Blob Data Reader" `
        --scope $storageAccount.Id `
        --only-show-errors

    if ($LASTEXITCODE -ne 0) {
        throw "az role assignment delete failed with exit code $LASTEXITCODE"
    }

    Write-Host "   ✅ Role removed successfully!" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to remove role: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Alternative: Remove manually in Azure Portal:" -ForegroundColor Yellow
    Write-Host "   1. Go to Storage Account -> Access Control (IAM)" -ForegroundColor Gray
    Write-Host "   2. Find the 'Storage Blob Data Reader' assignment for the Agent Identity" -ForegroundColor Gray
    Write-Host "   3. Click Remove" -ForegroundColor Gray
}
