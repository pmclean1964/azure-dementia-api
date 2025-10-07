param namePrefix string = 'dementia'
param location string = resourceGroup().location
@secure()
param apiKey string
param sqlServerFqdn string // e.g. dementia-sql-xxxxx.database.windows.net
param sqlDatabase string   // e.g. dementia
param sqlServerResourceGroup string
@description('DNS alias name to use for -dev- (server-level alias).')
param sqlAliasName string = 'dementia-dev-alias'

@description('Forces the alias repoint script to re-run each deployment.')
param forceRerun string = utcNow()

// Cloud-portable SQL host suffix (e.g., database.windows.net in Public)
var sqlHostSuffix = environment().suffixes.sqlServerHostname
var sqlAliasFqdn = '${sqlAliasName}.${sqlHostSuffix}'
var serverName = split(sqlServerFqdn, '.')[0]

resource stg 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: toLower('${namePrefix}funcstg')
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource ai 'Microsoft.Insights/components@2020-02-02' = {
  name: '${namePrefix}-appi'
  location: location
  kind: 'web'
  properties: { Application_Type: 'web' }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${namePrefix}-func-plan'
  location: location
  sku: { name: 'Y1', tier: 'Dynamic' } // Consumption
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: '${namePrefix}-func'
  location: location
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    httpsOnly: true
    serverFarmId: plan.id
    siteConfig: {
      appSettings: [
        { name: 'AzureWebJobsStorage', value: stg.properties.primaryEndpoints.blob }
        { name: 'FUNCTIONS_EXTENSION_VERSION', value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: ai.properties.ConnectionString }
        { name: 'API_KEY', value: apiKey }
        { name: 'SQL_SERVER', value: sqlAliasFqdn }
        { name: 'SQL_DATABASE', value: sqlDatabase }
        { name: 'SQL_ENCRYPT', value: 'true' }
      ]
      http20Enabled: true
    }
  }
}

// ---------- Azure SQL DNS Alias automation (dev) ----------

resource aliasScriptUami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'uami-alias-repoint-dev'
  location: location
}

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
  // Ensure RBAC is in place before the script runs
  dependsOn: [
    aliasRepointRole
  ]
  properties: {
    azCliVersion: '2.59.0'
    forceUpdateTag: forceRerun
    timeout: 'PT15M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
      set -euo pipefail

      RG='${sqlServerResourceGroup}'
      SERVER_NAME='${serverName}'
      ALIAS='${sqlAliasName}'

      echo "Ensuring SQL DNS alias '${sqlAliasName}' points to server '${serverName}' in RG '${resourceGroup().name}'..."

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

resource aliasRepointRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'alias-repoint-dev-role')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: aliasScriptUami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}


output principalId string = app.identity.principalId
output functionAppName string = app.name
output webAppUrl string = 'https://${app.properties.defaultHostName}'
output sqlServerFqdnOut string = sqlServerFqdn
output sqlServerName string = serverName
