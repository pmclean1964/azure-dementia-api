targetScope = 'resourceGroup'

@description('Azure region for resources (defaults to current RG location).')
param location string = resourceGroup().location

//@description('Short name of the Azure SQL logical server (no FQDN).')
//param sqlServerName string

@description('Database name to connect to on the server.')
param sqlDatabase string

@description('DNS alias name to use for -dev- (server-level alias).')
param sqlAliasName string = 'dementia-dev-alias'

@description('Optional tags to apply to resources created in this template.')
param tags object = {}

@description('Forces the deployment script to re-run each deployment (uses current UTC time by default).')
param forceRerun string = utcNow()

// Use environment() to avoid hardcoding cloud URLs
var sqlHostSuffix = environment().suffixes.sqlServerHostname
var sqlAliasFqdn = '${sqlAliasName}.${sqlHostSuffix}'

// -----------------------
// User-Assigned Managed Identity for the deployment script
// -----------------------
resource aliasScriptUami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uami-alias-repoint-dev'
  location: location
  tags: tags
}

// -----------------------
// Deployment Script (Azure CLI) to ensure alias exists or is repointed
// -----------------------
resource aliasRepoint 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'aliasRepoint-dev'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aliasScriptUami.id}': {}
    }
  }
  tags: tags
  properties: {
    azCliVersion: '2.59.0'
    forceUpdateTag: forceRerun
    timeout: 'PT15M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      set -euo pipefail

      RG='${resourceGroup().name}'
      SERVER_NAME='${sqlServerName}'
      ALIAS='${sqlAliasName}'

      echo "Ensuring SQL DNS alias '${sqlAliasName}' points to server '${sqlServerName}' in RG '${resourceGroup().name}'..."

      # 1) If alias already present on the desired server, exit.
      if az sql server dns-alias show --name "$ALIAS" --resource-group "$RG" --server "$SERVER_NAME" >/dev/null 2>&1; then
        echo "Alias '$ALIAS' already exists on '$SERVER_NAME'. Nothing to do."
        exit 0
      fi

      # 2) Try to create the alias on the current server.
      if az sql server dns-alias create --name "$ALIAS" --resource-group "$RG" --server "$SERVER_NAME" >/dev/null 2>&1; then
        echo "Created alias '$ALIAS' on '$SERVER_NAME'."
        exit 0
      fi

      # 3) If creation failed, alias likely exists on another server. Attempt a repoint from a prior server in this RG.
      echo "Create failed; attempting to repoint alias from a previous server in this resource group..."
      OLD_SERVER=$(az sql server list -g "$RG" --query "[?name!='$SERVER_NAME'].name" -o tsv | head -n 1 || true)

      if [ -n "${OLD_SERVER:-}" ]; then
        az sql server dns-alias set --name "$ALIAS" --original-server "$OLD_SERVER" --server "$SERVER_NAME"
        echo "Repointed alias '$ALIAS' from '$OLD_SERVER' to '$SERVER_NAME'."
      else
        echo "No previous server discovered in RG '$RG'. If the alias exists in another RG/subscription, run a one-time 'az sql server dns-alias set' there."
      fi
    '''
  }
}

// -----------------------
// Grant the UAMI permission to manage SQL alias (Contributor at RG scope)
// -----------------------
resource aliasRepointRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aliasScriptUami.name, 'contributor-role')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b24988ac-6180-42a0-ab88-20f7382dd24c' // Contributor
    )
    principalId: aliasScriptUami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// -----------------------
// Outputs (use these in your app / pipelines)
// -----------------------
@description('Stable server hostname your app should use (server-level DNS alias).')
output devSqlHost string = sqlAliasFqdn

@description('Convenience connection string using the alias.')
output devSqlConnection string = 'Server=tcp:${sqlAliasFqdn},1433;Initial Catalog=${sqlDatabase};Persist Security Info=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
