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
Write-Host "Storage account '$storage_acc_name' found in resource group '$rg_name'." -ForegroundColor Green
if (-not $storageAccount) {
    Write-Host "❌ Storage account '$storage_acc_name' not found in resource group '$rg_name'" -ForegroundColor Red
    exit 1
}

# Assign Storage Blob Data Reader role to Agent Identity
Write-Host "`n3️⃣ Assigning 'Storage Blob Data Reader' role to Agent Identity..." -ForegroundColor Yellow

$roleAssignment = az role assignment list `
    --assignee $agent_id_id `
    --role "Storage Blob Data Reader" `
    --scope $storageAccount.Id `
    --only-show-errors 2>$null | ConvertFrom-Json

if ($roleAssignment -and $roleAssignment.Count -gt 0) {
    Write-Host "   ⚠️ Role already assigned" -ForegroundColor Yellow
} else {
    try {
        az role assignment create `
            --assignee $agent_id_id `
            --role "Storage Blob Data Reader" `
            --scope $storageAccount.Id `
            --only-show-errors

        if ($LASTEXITCODE -ne 0) {
            throw "az role assignment create failed with exit code $LASTEXITCODE"
        }
        
        Write-Host "   ✅ Role assigned successfully!" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ Failed to assign role: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "   Alternative: Assign manually in Azure Portal:" -ForegroundColor Yellow
        Write-Host "   1. Go to Storage Account -> Access Control (IAM)" -ForegroundColor Gray
        Write-Host "   2. Add role assignment -> Storage Blob Data Reader" -ForegroundColor Gray
        Write-Host "   3. Select members -> Search for Agent Name" -ForegroundColor Gray
    }
}