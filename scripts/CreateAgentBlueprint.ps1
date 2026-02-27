<#
.SYNOPSIS
    Creates an Agent Identity Blueprint in Microsoft Entra ID.

.DESCRIPTION
    Authenticates to Microsoft Graph and creates a new Agent Identity Blueprint
    with the specified display name. The currently authenticated user is assigned
    as both the sponsor and owner of the blueprint.

.PARAMETER tenant_id
    The Azure tenant ID to authenticate against. If not passed, falls back to
    a session variable of the same name.

.PARAMETER blueprint_name
    The display name for the new Agent Identity Blueprint. If not passed, falls
    back to a session variable of the same name.

.EXAMPLE
    ./CreateAgentBlueprint.ps1 -tenant_id "00000000-0000-0000-0000-000000000000" -blueprint_name "MyBlueprint"

.EXAMPLE
    $tenant_id = "00000000-0000-0000-0000-000000000000"
    $blueprint_name = "MyBlueprint"
    ./CreateAgentBlueprint.ps1

.NOTES
    Requires the Microsoft Graph PowerShell SDK.
    Scopes: AgentIdentityBlueprint.ReadWrite.All, User.Read
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$tenant_id = $tenant_id,
    [string]$blueprint_name = $blueprint_name
)

# Validate that required variables are set (either passed or pre-set in session).
if (-not $tenant_id) {
    Write-Error "Error: `$tenant_id is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $blueprint_name) {
    Write-Error "Error: `$blueprint_name is not set. Pass it as a parameter or set it in your session."
    return
}

$requiredScopes = @(
    "AgentIdentityBlueprint.AddRemoveCreds.All",
    "AgentIdentityBlueprint.Create",
    "DelegatedPermissionGrant.ReadWrite.All",
    "Application.Read.All",
    "AgentIdentityBlueprintPrincipal.Create",
    "User.Read"
)

# Authenticate to Microsoft Graph with the required scopes for managing
Connect-MgGraph -Scopes $requiredScopes -TenantId $tenant_id -ErrorAction Stop


$blueprints = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/applications/graph.agentIdentityBlueprint" `
    -ErrorAction Stop

if ($blueprints.value.Count -gt 0) {
    $blueprints.value | Select-Object displayName, appId, id | Format-Table -AutoSize

    # Check if a blueprint with the same display name already exists.
    $existing = $blueprints.value | Where-Object { $_.displayName -eq $blueprint_name }
    if ($existing) {
        Write-Warning "A blueprint named '$blueprint_name' already exists."
        $response = Read-Host "Do you want to continue and create a duplicate? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Operation cancelled."
            return
        }
    }
}

# Retrieve the UPN (User Principal Name) of the currently authenticated user.
$currentUser = Get-MgContext | Select-Object -ExpandProperty Account

# Fetch the full user object from Microsoft Graph for the authenticated user.
$user = Get-MgUser -UserId $currentUser

# Display the authenticated user's name and object ID for confirmation.
Write-Host "Current user: $($user.DisplayName) ($($user.Id))"

# Construct the request body for creating a new Agent Identity Blueprint.
$body = @{
    # Specify the OData type for the Agent Identity Blueprint resource.
    "@odata.type"         = "Microsoft.Graph.AgentIdentityBlueprint"
    # Set the display name of the blueprint using the provided variable.
    "displayName"         = $blueprint_name
    # Designate the current user as the sponsor of this blueprint.
    "sponsors@odata.bind" = @("https://graph.microsoft.com/v1.0/users/$($user.Id)")
    # Designate the current user as the owner of this blueprint.
    "owners@odata.bind"   = @("https://graph.microsoft.com/v1.0/users/$($user.Id)")
} | ConvertTo-Json -Depth 5  # Convert the hashtable to JSON with sufficient depth.

# Issue a POST request to the Microsoft Graph beta endpoint to create the blueprint.
$params = @{
    Method      = "POST"
    Uri         = "https://graph.microsoft.com/beta/applications/graph.agentIdentityBlueprint"
    Headers     = @{ "OData-Version" = "4.0" }
    Body        = $body
    ContentType = "application/json"
}
$blueprint = Invoke-MgGraphRequest @params

$blueprintAppId = $blueprint.appId
$blueprintObjectId = $blueprint.id

# Create the Blueprint Principal (Service Principal) 
$principalBody = @{
    appId = $blueprintAppId
}

$principal = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/serviceprincipals/graph.agentIdentityBlueprintPrincipal" `
    -Headers @{ "OData-Version" = "4.0" } `
    -Body ($principalBody | ConvertTo-Json) `
    -ErrorAction Stop

# Create client secret for the Blueprint
$blueprintApp = (Invoke-MgGraphRequest -Method GET `
        -Uri "https://graph.microsoft.com/beta/applications?`$filter=appId eq '$blueprintAppId'" `
        -ErrorAction Stop).value[0]

$secretBody = @{
    passwordCredential = @{
        displayName = "Agent Identity Creation Secret - $(Get-Date -Format 'yyyy-MM-dd')"
        endDateTime = (Get-Date).AddYears(1).ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
}

$secret = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/applications/$($blueprintApp.id)/addPassword" `
    -Body ($secretBody | ConvertTo-Json -Depth 10) `
    -ErrorAction Stop

$result = [PSCustomObject]@{
    blueprint_name   = $blueprint_name
    blueprint_app_id = $blueprintApp.id
    blueprint_obj_id = $blueprintObjectId
    principal_id     = $principal.id
    secret_value     = $secret.secretText
    secret_id        = $secret.keyId
    secret_expiry    = $secret.endDateTime
    user_id          = $user.Id
}

return $result