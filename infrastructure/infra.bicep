param namePrefix string = 'dementia'
param location string = resourceGroup().location
@secure()
param apiKey string
param sqlServerFqdn string // e.g. dementia-sql-xxxxx.database.windows.net
param sqlDatabase string   // e.g. dementia

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
        { name: 'SQL_SERVER', value: sqlServerFqdn }
        { name: 'SQL_DATABASE', value: sqlDatabase }
        { name: 'SQL_ENCRYPT', value: 'true' }
      ]
      http20Enabled: true
    }
  }
}

output principalId string = app.identity.principalId
output functionAppName string = app.name
output webAppUrl string = 'https://${app.properties.defaultHostName}'
