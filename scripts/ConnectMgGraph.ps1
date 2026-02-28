$requiredBlueprintScopes = @(
    "AgentIdentityBlueprint.AddRemoveCreds.All",
    "AgentIdentityBlueprint.Create",
    "DelegatedPermissionGrant.ReadWrite.All",
    "Application.Read.All",
    "AgentIdentityBlueprintPrincipal.Create",
    "User.Read"
)

$requiredIdentityScopes = @(
    "AgentIdentity.ReadWrite.All",
    "AgentIdentityBlueprint.AddRemoveCreds.All",
    "AgentIdentityBlueprintPrincipal.Create",
    "AgentIdentityBlueprintPrincipal.ReadWrite.All",
    "Application.Read.All",
    "User.Read"
)

$requiredCredScopes = @(
    "AgentIdentityBlueprint.AddRemoveCreds.All",
    "Application.ReadWrite.All"
)


$requiredBlueprintWriteScopes = @(
    "AgentIdentityBlueprint.ReadWrite.All",
    "Application.ReadWrite.All"
)

# Authenticate to Microsoft Graph with the required scopes for managing
function ConnectMgGraphBlueprintScopes {
    param(
        [string]$TenantId
    )

    try {
        Connect-MgGraph -Scopes $requiredBlueprintScopes -TenantId $TenantId -ErrorAction Stop -NoWelcome
        Write-Host "Successfully authenticated to Microsoft Graph."
    } catch {
        Write-Error "Failed to authenticate to Microsoft Graph: $_"
    }
}

function ConnectMgGraphIdentityScopes {
    param(
        [string]$TenantId
    )

    try {
        Connect-MgGraph -Scopes $requiredIdentityScopes -TenantId $TenantId -ErrorAction Stop -NoWelcome
        Write-Host "Successfully authenticated to Microsoft Graph."
    } catch {
        Write-Error "Failed to authenticate to Microsoft Graph: $_"
    }
}

function ConnectMgGraphCredScopes {
    param(
        [string]$TenantId
    )

    try {
        Connect-MgGraph -Scopes $requiredCredScopes -TenantId $TenantId -ErrorAction Stop -NoWelcome
        Write-Host "Successfully authenticated to Microsoft Graph."
    } catch {
        Write-Error "Failed to authenticate to Microsoft Graph: $_"
    }
}

function ConnectMgGraphBlueprintWriteScopes {
    param(
        [string]$TenantId
    )

    try {
        Connect-MgGraph -Scopes $requiredBlueprintWriteScopes -TenantId $TenantId -ErrorAction Stop -NoWelcome
        Write-Host "Successfully authenticated to Microsoft Graph."
    } catch {
        Write-Error "Failed to authenticate to Microsoft Graph: $_"
    }
}  
