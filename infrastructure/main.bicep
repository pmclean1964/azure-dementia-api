// Bicep template to deploy minimal infrastructure for a serverless API on Azure Functions (Linux Consumption)
// - Creates Storage Account
// - Creates Linux Consumption App Service plan
// - Creates Function App (Functions v4, Node 18)
// - Configures app settings including Key Vault references for DB_* secrets
// - Grants the Function App access to Key Vault secrets via RBAC (Key Vault Secrets User)

@description('Azure region for all resources')
param location string

@description('Name of the Function App (must be globally unique)')
param functionAppName string

@description('Name of the Storage Account (3-24 lowercase alphanumeric, globally unique)')
param storageAccountName string

@description('Resource group name of the existing Key Vault that stores DB secrets (same subscription)')
param keyVaultResourceGroup string = resourceGroup().name

@description('Name of the existing Key Vault that stores DB secrets')
param keyVaultName string

@description('If true, create an RBAC role assignment on the Key Vault to grant the Function App identity access to secrets. Requires deployer to have Microsoft.Authorization/roleAssignments/write at the Key Vault scope.')
param enableKvRbacAssignment bool = false

@description('Secret name for DB FQDN in Key Vault')
param dbFqdnSecretName string = 'db-fqdn'

@description('Secret name for DB name in Key Vault')
param dbNameSecretName string = 'db-name'

@description('Secret name for DB login in Key Vault (optional)')
param dbLoginSecretName string = 'db-login'

@description('Secret name for DB password in Key Vault (optional)')
param dbPasswordSecretName string = 'db-password'

@description('Secret name for DB resource group in Key Vault')
param dbResourceGroupSecretName string = 'db-resource-group'

// Existing Key Vault reference (assumed to exist in the same subscription)
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
  scope: resourceGroup(keyVaultResourceGroup)
}

// Storage Account for AzureWebJobsStorage
resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// Build the connection string using a resource reference to listKeys()
var primaryStorageKey = stg.listKeys().keys[0].value
var storageConn = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${primaryStorageKey};EndpointSuffix=${environment().suffixes.storage}'

// Linux Consumption plan for Functions
resource plan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'plan-${uniqueString(resourceGroup().id, functionAppName)}'
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  properties: {
    reserved: true // Linux
  }
}

// Function App (Linux, Node 18)
resource func 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'Node|18'
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~18'
        }
        {
          name: 'AzureWebJobsStorage'
          value: storageConn
        }
        // DB settings resolved at runtime from Key Vault via App Service Key Vault references
        {
          name: 'DB_FQDN'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${dbFqdnSecretName})'
        }
        {
          name: 'DB_NAME'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${dbNameSecretName})'
        }
        {
          name: 'DB_LOGIN'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${dbLoginSecretName})'
        }
        {
          name: 'DB_PASSWORD'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${dbPasswordSecretName})'
        }
        {
          name: 'DB_RESOURCE_GROUP'
          value: '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/${dbResourceGroupSecretName})'
        }
      ]
    }
  }
}

// Grant Function App access to Key Vault secrets via RBAC (Key Vault Secrets User) via module at KV RG scope (optional)
module kvRole 'modules/kv-role.bicep' = if (enableKvRbacAssignment) {
  name: 'kvRole-${uniqueString(kv.id, functionAppName)}'
  scope: resourceGroup(keyVaultResourceGroup)
  params: {
    keyVaultName: keyVaultName
    principalId: func.identity.principalId
  }
}

output functionAppResourceId string = func.id
output storageAccountResourceId string = stg.id
output keyVaultResourceId string = kv.id
output functionAppNameOut string = functionAppName
output storageAccountNameOut string = storageAccountName
output functionAppDefaultHostname string = func.properties.defaultHostName
output functionAppBaseUrl string = 'https://${func.properties.defaultHostName}'
output apiBaseUrl string = 'https://${func.properties.defaultHostName}'
