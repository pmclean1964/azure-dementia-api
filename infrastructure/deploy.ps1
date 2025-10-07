param(
    [Parameter(Mandatory = $true)] [string] $SubscriptionId,
    [Parameter(Mandatory = $true)] [string] $Location,
    [Parameter(Mandatory = $true)] [string] $ResourceGroupName,
    [Parameter(Mandatory = $true)] [string] $FunctionAppName,
    [Parameter(Mandatory = $true)] [string] $StorageAccountName,
    [Parameter(Mandatory = $false)] [string] $KeyVaultName = "dementiadbsecrets"
)

# This script creates the minimal Azure infrastructure for a serverless API (Azure Functions)
# and retrieves database secrets from the specified Key Vault (defaults to 'dementiadbsecrets').
# It also applies the DB secrets as application settings on the Function App for easy consumption by the API code.
#
# Requirements:
# - Azure CLI installed and logged in: https://learn.microsoft.com/cli/azure/install-azure-cli
# - Appropriate permissions to create resources and read Key Vault secrets.
#
# Example usage:
#   pwsh ./infrastructure/deploy.ps1 `
#       -SubscriptionId "00000000-0000-0000-0000-000000000000" `
#       -Location "westeurope" `
#       -ResourceGroupName "rg-dementia-api" `
#       -FunctionAppName "func-dementia-api-001" `
#       -StorageAccountName "stgdementiaapi001"

$ErrorActionPreference = "Stop"

Write-Host "Setting subscription to $SubscriptionId" -ForegroundColor Cyan
az account set --subscription $SubscriptionId | Out-Null

Write-Host "Ensuring resource group '$ResourceGroupName' in '$Location'" -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location | Out-Null

# Create a general-purpose v2 Storage Account (required by Azure Functions)
Write-Host "Ensuring storage account '$StorageAccountName'" -ForegroundColor Cyan
az storage account create `
  --name $StorageAccountName `
  --resource-group $ResourceGroupName `
  --location $Location `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 | Out-Null

# Retrieve storage connection string for AzureWebJobsStorage
$storageConnectionString = az storage account show-connection-string `
  --name $StorageAccountName `
  --resource-group $ResourceGroupName `
  --query connectionString -o tsv

# Create a Consumption plan Function App on Linux, Node.js 18
Write-Host "Ensuring Function App '$FunctionAppName' (Linux Consumption, Node.js 18)" -ForegroundColor Cyan
# Create the function app (will be idempotent)
az functionapp create `
  --name $FunctionAppName `
  --resource-group $ResourceGroupName `
  --storage-account $StorageAccountName `
  --consumption-plan-location $Location `
  --functions-version 4 `
  --runtime node `
  --runtime-version 18 `
  --os-type Linux | Out-Null

# Apply required base app settings
Write-Host "Configuring base app settings" -ForegroundColor Cyan
az functionapp config appsettings set `
  --name $FunctionAppName `
  --resource-group $ResourceGroupName `
  --settings `
    "FUNCTIONS_WORKER_RUNTIME=node" `
    "WEBSITE_NODE_DEFAULT_VERSION=~18" `
    "AzureWebJobsStorage=$storageConnectionString" | Out-Null

# Configure managed identity and Key Vault references so the app reads DB info from Key Vault at runtime
Write-Host "Ensuring system-assigned managed identity on the Function App" -ForegroundColor Cyan
az functionapp identity assign --name $FunctionAppName --resource-group $ResourceGroupName | Out-Null
$principalId = az functionapp identity show --name $FunctionAppName --resource-group $ResourceGroupName --query principalId -o tsv

# Grant Key Vault access via RBAC (Key Vault should use Azure RBAC for secrets)
$kvId = az keyvault show --name $KeyVaultName --query id -o tsv
Write-Host "Granting 'Key Vault Secrets User' role to Function App identity on Key Vault" -ForegroundColor Cyan
# Create role assignment; ignore error if it already exists
try {
  az role assignment create `
    --assignee-object-id $principalId `
    --assignee-principal-type ServicePrincipal `
    --role "Key Vault Secrets User" `
    --scope $kvId | Out-Null
} catch {
  Write-Host "Role assignment may already exist; continuing" -ForegroundColor Yellow
}

# Apply DB settings as Key Vault references (no secrets stored in app settings)
Write-Host "Applying DB Key Vault reference app settings to Function App" -ForegroundColor Cyan
$kvBase = "https://$KeyVaultName.vault.azure.net/secrets"
$settings = @(
  "DB_FQDN=@Microsoft.KeyVault(SecretUri=$kvBase/db-fqdn)",
  "DB_NAME=@Microsoft.KeyVault(SecretUri=$kvBase/db-name)",
  "DB_LOGIN=@Microsoft.KeyVault(SecretUri=$kvBase/db-login)",
  "DB_PASSWORD=@Microsoft.KeyVault(SecretUri=$kvBase/db-password)",
  "DB_RESOURCE_GROUP=@Microsoft.KeyVault(SecretUri=$kvBase/db-resource-group)"
)

az functionapp config appsettings set `
  --name $FunctionAppName `
  --resource-group $ResourceGroupName `
  --settings $settings | Out-Null

# Output a summary object for automation pipelines
Write-Output (ConvertTo-Json -Depth 4 @{ 
  subscriptionId = $SubscriptionId
  location = $Location
  resourceGroupName = $ResourceGroupName
  functionAppName = $FunctionAppName
  storageAccountName = $StorageAccountName
  keyVaultName = $KeyVaultName
  appSettings = @{ 
    FUNCTIONS_WORKER_RUNTIME = "node"
    WEBSITE_NODE_DEFAULT_VERSION = "~18"
  }
  db = @{ 
    fqdn = $FQDN
    name = $DBNAME
    login = $DBLOGIN
    passwordSet = [bool]($DBPASS)
    resourceGroup = $DBRG
  }
})
