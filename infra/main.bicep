@description('Azure region for the resources (e.g., eastus, westeurope).')
param location string

@description('Name of the Web App (must be globally unique).')
param name string

@description('App Service Plan SKU (size). Change for more/less capacity. Common values: F1, B1, B2, B3, S1, P1v3, etc.')
@allowed([
  'F1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v3'
  'P2v3'
  'P3v3'
])
param sku string = 'B1'

// Optional: resourceGroupName is not used directly; included for clarity in comments and outputs if desired.
@description('(Optional) Resource Group name (informational). Not used in deployment logic.')
param resourceGroupName string = resourceGroup().name

// ================================
// App Service Plan (Linux)
// ================================
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${name}-plan'
  location: location
  sku: {
    name: sku
    tier: sku == 'F1' ? 'Free' : (sku startsWith 'B' ? 'Basic' : (sku startsWith 'S' ? 'Standard' : 'PremiumV3'))
    size: sku
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true // required for Linux
  }
}

// ================================
// Web App (Linux) configured for Node 20
// ================================
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: plan.id
    siteConfig: {
      // Runtime stack: Node 20 LTS on Linux
      linuxFxVersion: 'Node|20 LTS' // To change runtime, update this string. Examples: Node|18 LTS, Node|22 LTS
      appSettings: [
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '0'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~20'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
      ]
      alwaysOn: true
      http20Enabled: true
    }
    httpsOnly: true
  }
}

output defaultHostName string = webApp.properties.defaultHostName
