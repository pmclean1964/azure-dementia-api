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

CI/CD with GitHub Actions
- This repo includes a workflow at .github/workflows/deploy-infra.yml that deploys the Bicep template using Azure OIDC.
- Configure the following repository/environment secrets for azure/login:
  - AZURE_CLIENT_ID — Federated credential-enabled app registration/client ID
  - AZURE_TENANT_ID — Azure AD tenant ID
  - AZURE_SUBSCRIPTION_ID — Subscription ID to deploy into
- Provide parameters either as workflow_dispatch inputs when manually running, or via repository Variables (Settings > Variables):
  - RESOURCE_GROUP_NAME
  - AZURE_LOCATION (e.g., eastus2)
  - FUNCTION_APP_NAME
  - STORAGE_ACCOUNT_NAME
  - KEY_VAULT_RESOURCE_GROUP
  - KEY_VAULT_NAME
- Optional: You may also supply a parameters JSON file path via the parametersFile input (defaults to infrastructure/parameters.example.json). Any missing inputs/variables will be read from this file if present.
- Note: The parameters file may optionally include resourceGroupName; if present, the workflow will read it to set the target resource group when inputs/variables are missing.
- Manual run example (from GitHub UI):
  - Run workflow "Deploy Infrastructure (Bicep)" with inputs:
    - resourceGroupName=rg-dementia-api
    - location=eastus2
    - functionAppName=func-dementia-api-001
    - storageAccountName=stgdementiaapi001
    - keyVaultResourceGroup=rg-dementia-api
    - keyVaultName=dementiadbsecrets
    - parametersFile=infrastructure/parameters.example.json
  - Optionally enable whatIf=true to preview changes.
- On push to main affecting files under infrastructure/**, the workflow will deploy using repository Variables when inputs are not provided. If any required values are still missing, it will attempt to read them from the default parameters file before failing with guidance.
- Note: If the specified resource group already exists in a different location than requested, the workflow will now fail with guidance (see next section) to ensure all resources are created in the intended region (e.g., eastus2).


Key Vault access and RBAC permissions
- The template uses App Service Key Vault references for DB_* settings. The Function App’s managed identity must be able to read secrets from the specified Key Vault.
- New parameter: enableKvRbacAssignment (bool, default false). When set to true, the deployment will attempt to assign the Key Vault Secrets User role to the Function App identity at the Key Vault scope. This requires the deploying principal to have Microsoft.Authorization/roleAssignments/write on the Key Vault or its resource group/subscription.
- If you do not have permissions to create role assignments (common in GitHub Actions with limited rights), leave enableKvRbacAssignment=false and grant the Function App identity access to the Key Vault out-of-band (e.g., by a privileged operator or a separate pipeline).
- To enable via CLI parameters:
  az deployment group create ^
    --resource-group <rg> ^
    --template-file infrastructure\main.bicep ^
    --parameters enableKvRbacAssignment=true keyVaultName=<kv> ...
- To enable via parameters file, set:
  "enableKvRbacAssignment": { "value": true }

Troubleshooting
- Error: Authorization failed for template resource '.../providers/Microsoft.Authorization/roleAssignments/...'. The client '<objectId>' does not have permission to perform action 'Microsoft.Authorization/roleAssignments/write' ...
  - Cause: The deploying identity lacks rights to create RBAC assignments at the Key Vault scope.
  - Fix options:
    1) Run deployment with enableKvRbacAssignment=false (default) and grant Key Vault access separately; or
    2) Have a privileged identity run the deployment with enableKvRbacAssignment=true; or
    3) If your Key Vault uses access policies (not Azure RBAC), grant the Function App identity get/list permissions on secrets via access policies.


How to find your API endpoint (Function App URL)
- After deployment completes, you can discover the base URL and function routes in a few ways:

1) From deployment outputs (recommended)
- The Bicep template outputs apiBaseUrl (alias) and functionAppBaseUrl, plus functionAppDefaultHostname.
- Using Azure CLI, fetch them:
  az deployment group show ^
    --resource-group rg-dementia-api ^
    --name main ^
    --query "properties.outputs.{url:apiBaseUrl.value, host:functionAppDefaultHostname.value}" -o tsv
- The base URL will look like: https://<your-func-app>.azurewebsites.net
- Function invocation URLs follow: https://<your-func-app>.azurewebsites.net/api/<FunctionName>

2) Via Azure CLI directly on the Function App
- Get the default hostname:
  az functionapp show -g rg-dementia-api -n func-dementia-api-001 --query defaultHostName -o tsv
- List functions deployed to the app:
  az functionapp function list -g rg-dementia-api -n func-dementia-api-001 -o table
- Construct the URL as: https://<defaultHostName>/api/<FunctionName>

3) In Azure Portal
- Go to your Function App > Overview. Copy the Default domain or click Browse.
- Go to Functions blade to see function names and use Get Function URL.

Function keys and authorization
- If your HTTP-trigger function uses authLevel=function or admin, you need a key.
- Retrieve a function key with CLI:
  az functionapp function keys list -g rg-dementia-api -n func-dementia-api-001 --function-name <FunctionName> --query default -o tsv
- Then call: https://<defaultHostName>/api/<FunctionName>?code=<the-key>
- If authLevel=anonymous, no key is required.

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
   az group create --name rg-dementia-api --location eastus2

2) Deploy the Bicep template to the resource group (replace values as needed):
   az deployment group create ^
     --resource-group rg-dementia-api ^
     --template-file infrastructure\main.bicep ^
     --parameters @infrastructure\parameters.example.json

   Or pass parameters inline, for example:
   az deployment group create ^
     --resource-group rg-dementia-api ^
     --template-file infrastructure\main.bicep ^
     --parameters location=eastus2 functionAppName=func-dementia-api-001 storageAccountName=stgdementiaapi001 ^
                 keyVaultResourceGroup=rg-dementia-api keyVaultName=dementiadbsecrets

 Notes
 - Storage account names must be globally unique and 3-24 lowercase alphanumeric.
 - Function App names must be globally unique within Azure.
 - This template uses App Service Key Vault references so the Function App reads secret values at runtime. Ensure the Function App managed identity has access to the Key Vault (the template assigns the Key Vault Secrets User role if Key Vault uses RBAC).
 - If your Key Vault uses access policies (not RBAC), grant the Function App identity get/list permissions on secrets manually, or adapt the template to manage access policies in that Key Vault resource scope.
 - The template defaults the location parameter to the resource group's location. If you pass a location, ensure it matches the resource group region.
 - To preview changes without applying them, use:
   az deployment group what-if --resource-group rg-dementia-api --template-file infrastructure\main.bicep --parameters @infrastructure\parameters.example.json

Migration note
- We have migrated from a PowerShell (Azure CLI) script to Bicep for declarative, repeatable deployments. The legacy script remains available at infrastructure/deploy.ps1 for now but is deprecated.

CI/CD with GitHub Actions
- This repo includes a workflow at .github/workflows/deploy-infra.yml that deploys the Bicep template using Azure OIDC.
- Configure the following repository/environment secrets for azure/login:
  - AZURE_CLIENT_ID — Federated credential-enabled app registration/client ID
  - AZURE_TENANT_ID — Azure AD tenant ID
  - AZURE_SUBSCRIPTION_ID — Subscription ID to deploy into
- Provide parameters either as workflow_dispatch inputs when manually running, or via repository Variables (Settings > Variables):
  - RESOURCE_GROUP_NAME
  - AZURE_LOCATION (e.g., eastus2)
  - FUNCTION_APP_NAME
  - STORAGE_ACCOUNT_NAME
  - KEY_VAULT_RESOURCE_GROUP
  - KEY_VAULT_NAME
- Optional: You may also supply a parameters JSON file path via the parametersFile input (defaults to infrastructure/parameters.example.json). Any missing inputs/variables will be read from this file if present.
- Note: The parameters file may optionally include resourceGroupName; if present, the workflow will read it to set the target resource group when inputs/variables are missing.
- Manual run example (from GitHub UI):
  - Run workflow "Deploy Infrastructure (Bicep)" with inputs:
    - resourceGroupName=rg-dementia-api
    - location=eastus2
    - functionAppName=func-dementia-api-001
    - storageAccountName=stgdementiaapi001
    - keyVaultResourceGroup=rg-dementia-api
    - keyVaultName=dementiadbsecrets
    - parametersFile=infrastructure/parameters.example.json
  - Optionally enable whatIf=true to preview changes.
- On push to main affecting files under infrastructure/**, the workflow will deploy using repository Variables when inputs are not provided. If any required values are still missing, it will attempt to read them from the default parameters file before failing with guidance.
- Note: If the specified resource group already exists in a different location than requested, the workflow will now fail with guidance (see next section) to ensure all resources are created in the intended region (e.g., eastus2).


Key Vault access and RBAC permissions
- The template uses App Service Key Vault references for DB_* settings. The Function App’s managed identity must be able to read secrets from the specified Key Vault.
- New parameter: enableKvRbacAssignment (bool, default false). When set to true, the deployment will attempt to assign the Key Vault Secrets User role to the Function App identity at the Key Vault scope. This requires the deploying principal to have Microsoft.Authorization/roleAssignments/write on the Key Vault or its resource group/subscription.
- If you do not have permissions to create role assignments (common in GitHub Actions with limited rights), leave enableKvRbacAssignment=false and grant the Function App identity access to the Key Vault out-of-band (e.g., by a privileged operator or a separate pipeline).
- To enable via CLI parameters:
  az deployment group create ^
    --resource-group <rg> ^
    --template-file infrastructure\main.bicep ^
    --parameters enableKvRbacAssignment=true keyVaultName=<kv> ...
- To enable via parameters file, set:
  "enableKvRbacAssignment": { "value": true }

Troubleshooting
- Error: Authorization failed for template resource '.../providers/Microsoft.Authorization/roleAssignments/...'. The client '<objectId>' does not have permission to perform action 'Microsoft.Authorization/roleAssignments/write' ...
  - Cause: The deploying identity lacks rights to create RBAC assignments at the Key Vault scope.
  - Fix options:
    1) Run deployment with enableKvRbacAssignment=false (default) and grant Key Vault access separately; or
    2) Have a privileged identity run the deployment with enableKvRbacAssignment=true; or
    3) If your Key Vault uses access policies (not Azure RBAC), grant the Function App identity get/list permissions on secrets via access policies.

How to find your API endpoint (Function App URL)
- After deployment completes, you can discover the base URL and function routes in a few ways:

1) From deployment outputs (recommended)
- The Bicep template outputs apiBaseUrl (alias) and functionAppBaseUrl, plus functionAppDefaultHostname.
- Using Azure CLI, fetch them:
  az deployment group show ^
    --resource-group rg-dementia-api ^
    --name main ^
    --query "properties.outputs.{url:apiBaseUrl.value, host:functionAppDefaultHostname.value}" -o tsv
- The base URL will look like: https://<your-func-app>.azurewebsites.net
- Function invocation URLs follow: https://<your-func-app>.azurewebsites.net/api/<FunctionName>

2) Via Azure CLI directly on the Function App
- Get the default hostname:
  az functionapp show -g rg-dementia-api -n func-dementia-api-001 --query defaultHostName -o tsv
- List functions deployed to the app:
  az functionapp function list -g rg-dementia-api -n func-dementia-api-001 -o table
- Construct the URL as: https://<defaultHostName>/api/<FunctionName>

3) In Azure Portal
- Go to your Function App > Overview. Copy the Default domain or click Browse.
- Go to Functions blade to see function names and use Get Function URL.

Function keys and authorization
- If your HTTP-trigger function uses authLevel=function or admin, you need a key.
- Retrieve a function key with CLI:
  az functionapp function keys list -g rg-dementia-api -n func-dementia-api-001 --function-name <FunctionName> --query default -o tsv
- Then call: https://<defaultHostName>/api/<FunctionName>?code=<the-key>
- If authLevel=anonymous, no key is required.

Region and resource group location enforcement
- The Bicep template restricts the location parameter to eastus2. Deployments providing any other region will fail validation before creating resources.
- This repository also enforces that the existing resource group location must match the requested deployment location to avoid accidental cross-region deployments.
- If the RG exists in a different region (e.g., westeurope) than requested (e.g., eastus2), the workflow will fail with guidance instead of reusing it.
- To proceed, either:
  1) Choose a new resourceGroupName that doesn’t exist and will be created in the requested location; or
  2) Delete/recreate the existing RG in the desired region; or
  3) Adjust the requested location to match the existing RG’s region.
