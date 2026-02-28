<#
.SYNOPSIS
    Creates an Agent Identity from an Agent Blueprint in Microsoft Entra ID.

.DESCRIPTION
    Authenticates to Microsoft Graph, acquires a blueprint token using client
    credentials, checks for existing agent identities with the same name, and
    creates a new Agent Identity linked to the specified blueprint. The current
    user or a specified user is assigned as the sponsor.

.PARAMETER tenant_id
    The Azure tenant ID to authenticate against. Falls back to a session
    variable if not passed.

.PARAMETER agent_id_name
    The display name for the new Agent Identity. Falls back to a session
    variable if not passed.

.PARAMETER blueprint_app_id
    The app ID of the Agent Blueprint to create the identity from. Falls back
    to a session variable if not passed.

.PARAMETER client_secret
    The client secret for the Agent Blueprint, used to acquire a blueprint
    token via client credentials flow. Falls back to a session variable if
    not passed.

.PARAMETER sponsor_user_id
    The object ID of the user to assign as sponsor of the Agent Identity.
    Falls back to a session variable if not passed.

.EXAMPLE
    ./CreateAgentIdentity.ps1 -tenant_id "00000000-..." -agent_id_name "MyAgent" -blueprint_app_id "11111111-..." -client_secret "secret" -sponsor_user_id "22222222-..."

.EXAMPLE
    $tenant_id = "00000000-..."
    $agent_id_name = "MyAgent"
    $blueprint_app_id = "11111111-..."
    $client_secret = "secret"
    $sponsor_user_id = "22222222-..."
    ./CreateAgentIdentity.ps1

.NOTES
    Requires the Microsoft Graph PowerShell SDK.
    Scopes: AgentIdentity.ReadWrite.All, AgentIdentityBlueprint.AddRemoveCreds.All,
            AgentIdentityBlueprintPrincipal.Create, AgentIdentityBlueprintPrincipal.ReadWrite.All,
            Application.Read.All, User.Read
    Returns a PSCustomObject with agent_id_name, agent_id_app_id,
    agent_id_id, blueprint_app_id, and tenant_id.
#>

# Accept optional parameters; fall back to session variables if not provided.
param(
    [string]$tenant_id = $tenant_id,
    [string]$agent_id_name = $agent_id_name,
    [string]$blueprint_app_id = $blueprint_app_id,
    [string]$client_secret = $client_secret,
    [string]$sponsor_user_id = $sponsor_user_id
)

# Validate that required variables are set (either passed or pre-set in session).
if (-not $tenant_id) {
    Write-Error "Error: `$tenant_id is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $agent_id_name) {
    Write-Error "Error: `$agent_id_name is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $blueprint_app_id) {
    Write-Error "Error: `$blueprint_app_id is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $client_secret) {
    Write-Error "Error: `$client_secret is not set. Pass it as a parameter or set it in your session."
    return
}
if (-not $sponsor_user_id) {
    Write-Error "Error: `$sponsor_user_id is not set. Pass it as a parameter or set it in your session."
    return
}

. ./ConnectMgGraph.ps1

ConnectMgGraphIdentityScopes -TenantId $tenant_id


function Get-BlueprintToken {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,
        
        [Parameter(Mandatory)]
        [string]$BlueprintAppId,
        
        [Parameter(Mandatory)]
        [string]$ClientSecret
    )

    $tokenBody = @{
        client_id     = $BlueprintAppId
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
        client_secret = $ClientSecret
    }

    $tokenEndpoint = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"

    try {
        $tokenResponse = Invoke-RestMethod -Method POST `
            -Uri $tokenEndpoint `
            -ContentType "application/x-www-form-urlencoded" `
            -Body $tokenBody `
            -ErrorAction Stop

        return $tokenResponse.access_token
    } catch {
        $errorResponse = $_.ErrorDetails.Message
        if ($errorResponse) {
            Write-Error "Token Error Response: $errorResponse"
        }
        throw "Failed to acquire Blueprint token: $($_.Exception.Message)"
    }
}

function Get-CurrentUserId {
    try {
        # Try using existing Graph connection
        $me = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/me" -ErrorAction Stop
        return $me.id
    } catch {
        Write-Warning "Could not get current user ID. Graph connection may be required."
        return $null
    }
}

$blueprintToken = Get-BlueprintToken -TenantId $tenant_id -BlueprintAppId $blueprint_app_id -ClientSecret $client_secret

# Step 1: List existing Agent Identities using the delegated session.
$listResponse = Invoke-MgGraphRequest -Method GET `
    -Uri "https://graph.microsoft.com/beta/servicePrincipals/graph.agentIdentity" `
    -ErrorAction Stop

if ($listResponse.value.Count -gt 0) {
    $listResponse.value | Select-Object displayName, appId, id | Format-Table -AutoSize

    # Check if an agent identity with the same display name already exists.
    $existing = $listResponse.value | Where-Object { $_.displayName -eq $agent_id_name }
    if ($existing) {
        Write-Warning "An agent identity named '$agent_id_name' already exists."
        $response = Read-Host "Do you want to continue and create a duplicate? (y/N)"
        if ($response -ne 'y') {
            Write-Host "Operation cancelled."
            return
        }
    }
}

# Step 2: Create Agent Identity
$agentIdentityBody = @{
    displayName              = $agent_id_name
    agentIdentityBlueprintId = $blueprint_app_id
    "sponsors@odata.bind"    = @(
        "https://graph.microsoft.com/v1.0/users/$($sponsor_user_id)"
    )
}


$headers = @{
    "Authorization" = "Bearer $blueprintToken"
    "OData-Version" = "4.0"
    "Content-Type"  = "application/json"
}

try {
    $agentIdentity = Invoke-RestMethod -Method POST `
        -Uri "https://graph.microsoft.com/beta/servicePrincipals/graph.agentIdentity" `
        -Headers $headers `
        -Body ($agentIdentityBody | ConvertTo-Json -Depth 10) `
        -ErrorAction Stop

    Write-Host "Agent Identity created!"
} catch {
    # Capture and display the full error response for debugging.
    $errorResponse = $_.ErrorDetails.Message
    if ($errorResponse) {
        Write-Error "API Error Response: $errorResponse"
    }
    throw "Failed to create Agent Identity: $($_.Exception.Message)"
}

$result = [PSCustomObject]@{
    agent_id_name    = $agent_id_name
    agent_id_app_id  = $agentIdentity.appId
    agent_id_id      = $agentIdentity.id
    blueprint_app_id = $blueprint_app_id
    tenant_id        = $tenant_id
}
return $result