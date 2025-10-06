param namePrefix string = 'dementia'
param location string = resourceGroup().location
@secure()
param apiKey string
param sqlServerFqdn string // e.g. dementia-sql-xxxxx.database.windows.net
param sqlDatabase string   // e.g. dementia

@description('Alias name for Azure SQL logical server (-dev- environment)')
param sqlAliasName string = 'dementia-dev-alias'

var sqlAliasFqdn = '${sqlAliasName}.database.windows.net'

// Extract the logical server name (left of .database.windows.net) from provided FQDN
var sqlServerName = split(sqlServerFqdn, '.')[0]

// Optional: resource group of the SQL server; default to current RG
@description('Resource group containing the Azure SQL server for -dev-')
param sqlServerResourceGroup string = resourceGroup().name

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


// System-assigned identity for the deployment script will be used to run az CLI
resource dnsAliasScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${namePrefix}-dev-dnsalias'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    azCliVersion: '2.58.0'
    timeout: 'PT15M'
    retentionInterval: 'P1D'
    cleanupPreference: 'OnSuccess'
    scriptContent: '''
# Fail fast
set -euo pipefail

echo "Ensuring DNS alias exists and points to current server"
SERVER_NAME="${sqlServerName}"
ALIAS_NAME="${sqlAliasName}"
RG="${sqlServerResourceGroup}"

# Check if alias exists on this server
if az sql server dns-alias show --resource-group "$RG" --server "$SERVER_NAME" --name "$ALIAS_NAME" >/dev/null 2>&1; then
  echo "Alias exists on current server; nothing to do."
else
  # If alias exists on another server, 'set' will move it ("acquire")
  if az sql server dns-alias list --resource-group "$RG" --server "$SERVER_NAME" --query "[?name=='$ALIAS_NAME']" -o tsv | grep -q "$ALIAS_NAME"; then
    echo "Alias found on current server list (race condition) - skipping."
  else
    # Try create (idempotent if not exists on any server)
    if az sql server dns-alias create --resource-group "$RG" --server "$SERVER_NAME" --name "$ALIAS_NAME"; then
      echo "Alias created on current server."
    else
      echo "Create failed (likely exists on another server). Attempting to repoint."
      # Discover original server by scanning servers in RG (fallback)
      # NOTE: If alias is in another RG/subscription, you may need to pass that RG explicitly via parameter.
      for s in $(az sql server list -g "$RG" --query "[].name" -o tsv); do
        if az sql server dns-alias show -g "$RG" -s "$s" -n "$ALIAS_NAME" >/dev/null 2>&1; then
          echo "Alias currently on server: $s. Repointing to $SERVER_NAME..."
          az sql server dns-alias set --name "$ALIAS_NAME" --original-server "$s" --server "$SERVER_NAME" -g "$RG"
          echo "Repointed."
          exit 0
        fi
      done
      echo "Could not determine original server; attempting direct set without original (may fail)."
      az sql server dns-alias set --name "$ALIAS_NAME" --server "$SERVER_NAME" -g "$RG" || true
    fi
  fi
fi

echo "Alias now should resolve to ${sqlAliasFqdn}"
    '''
    environmentVariables: [
      {
        name: 'ARM_USE_MSI'
        value: 'true'
      }
    ]
  }
}

// Grant the script permission on the SQL servers in the RG (Contributor at RG scope)
resource grantScriptRG 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, dnsAliasScript.name, 'contrib')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: dnsAliasScript.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output principalId string = app.identity.principalId
output functionAppName string = app.name
output webAppUrl string = 'https://${app.properties.defaultHostName}'
