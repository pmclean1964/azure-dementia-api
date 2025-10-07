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

# Retrieve DB secrets from Key Vault
Write-Host "Retrieving DB secrets from Key Vault: $KeyVaultName" -ForegroundColor Cyan
$FQDN = az keyvault secret show --vault-name $KeyVaultName --name "db-fqdn" --query value -o tsv
$DBNAME = az keyvault secret show --vault-name $KeyVaultName --name "db-name" --query value -o tsv
# 'db-login' and 'db-password' may be optional in some environments
$DBLOGIN = $null
$DBPASS = $null
try { $DBLOGIN = az keyvault secret show --vault-name $KeyVaultName --name "db-login" --query value -o tsv } catch { Write-Host "db-login not found or not accessible; continuing" -ForegroundColor Yellow }
try { $DBPASS = az keyvault secret show --vault-name $KeyVaultName --name "db-password" --query value -o tsv } catch { Write-Host "db-password not found or not accessible; continuing" -ForegroundColor Yellow }
$DBRG = az keyvault secret show --vault-name $KeyVaultName --name "db-resource-group" --query value -o tsv

Write-Host "Secrets retrieved:" -ForegroundColor Green
Write-Host "  db-fqdn:           $FQDN"
Write-Host "  db-name:           $DBNAME"
Write-Host "  db-login:          $DBLOGIN"
Write-Host "  db-password:       $(if ($DBPASS) { '***' } else { '' })"
Write-Host "  db-resource-group: $DBRG"

# Apply DB secrets as app settings to the Function App
Write-Host "Applying DB secrets to Function App settings" -ForegroundColor Cyan
$settings = @(
  "DB_FQDN=$FQDN",
  "DB_NAME=$DBNAME",
  "DB_LOGIN=$DBLOGIN",
  "DB_PASSWORD=$DBPASS",
  "DB_RESOURCE_GROUP=$DBRG"
) | Where-Object { $_ -and $_ -notmatch "=\s*$" } # drop empty values

if ($settings.Count -gt 0) {
  az functionapp config appsettings set `
    --name $FunctionAppName `
    --resource-group $ResourceGroupName `
    --settings $settings | Out-Null
}

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
