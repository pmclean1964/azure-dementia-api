targetScope = 'resourceGroup'

@description('Name of the existing Key Vault in this resource group')
param keyVaultName string

@description('Principal ID (objectId) to grant Key Vault Secrets User role')
param principalId string

// Existing Key Vault in this resource group
resource kv 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// Assign Key Vault Secrets User role to the principal at the Key Vault scope
resource kvSecretsRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, principalId, 'kv-secrets-user')
  scope: kv
  properties: {
    principalId: principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalType: 'ServicePrincipal'
  }
}
