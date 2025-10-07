Infrastructure deployment for serverless API on Azure (Bicep)

This folder now contains a Bicep template to provision the minimal infrastructure required to host an Azure Functions-based serverless API and to configure database settings via Key Vault references.

What gets deployed
- Storage Account (required by Azure Functions)
- Linux Consumption App Service plan (Y1)
- Azure Function App (Functions v4, Node.js 18) with system-assigned managed identity
- App settings including Key Vault references for DB_FQDN, DB_NAME, DB_LOGIN, DB_PASSWORD, DB_RESOURCE_GROUP
- RBAC role assignment granting the Function App identity access to Key Vault secrets (Key Vault Secrets User)

Prerequisites
- Azure CLI installed and logged in: https://learn.microsoft.com/cli/azure/install-azure-cli
- Permissions to create resources in the target subscription/resource group.
- Permissions to assign RBAC on the existing Key Vault (Key Vault should use Azure RBAC for secrets access).
- An existing Key Vault that contains these secrets:
  - db-fqdn
  - db-name
  - db-login (optional)
  - db-password (optional)
  - db-resource-group

Files
- infrastructure/main.bicep — main template
- infrastructure/parameters.example.json — example parameters file
- infrastructure/deploy.ps1 — legacy imperative deployment (deprecated; kept for reference)

How to deploy
1) Create or select a resource group (if not already created):
   az group create --name rg-dementia-api --location westeurope

2) Deploy the Bicep template to the resource group (replace values as needed):
   az deployment group create ^
     --resource-group rg-dementia-api ^
     --template-file infrastructure\main.bicep ^
     --parameters @infrastructure\parameters.example.json

   Or pass parameters inline, for example:
   az deployment group create ^
     --resource-group rg-dementia-api ^
     --template-file infrastructure\main.bicep ^
     --parameters location=westeurope functionAppName=func-dementia-api-001 storageAccountName=stgdementiaapi001 ^
                 keyVaultResourceGroup=rg-shared-secrets keyVaultName=dementiadbsecrets

Notes
- Storage account names must be globally unique and 3-24 lowercase alphanumeric.
- Function App names must be globally unique within Azure.
- This template uses App Service Key Vault references so the Function App reads secret values at runtime. Ensure the Function App managed identity has access to the Key Vault (the template assigns the Key Vault Secrets User role if Key Vault uses RBAC).
- If your Key Vault uses access policies (not RBAC), grant the Function App identity get/list permissions on secrets manually, or adapt the template to manage access policies in that Key Vault resource scope.
- To preview changes without applying them, use:
   az deployment group what-if --resource-group rg-dementia-api --template-file infrastructure\main.bicep --parameters @infrastructure\parameters.example.json

Migration note
- We have migrated from a PowerShell (Azure CLI) script to Bicep for declarative, repeatable deployments. The legacy script remains available at infrastructure/deploy.ps1 for now but is deprecated.
