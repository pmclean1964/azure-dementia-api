# dementia_api_serverless (Azure Functions, Managed Identity, Swagger, API key)

Serverless version of the Dementia API for the Family and Patient KIOSKs.

## Tech
- Azure Functions (Node.js v4, Consumption) — scales to zero (serverless)
- Azure SQL via Managed Identity (no passwords) using `mssql` + `@azure/identity`
- Custom API key header `x-api-key` enforced on all customer endpoints
- Swagger UI at `/swagger` (static function) and spec at `/swagger.json`
- Bicep + GitHub Actions (OIDC) to provision and deploy

## Endpoints
- `GET /api/v1/families/{id}` — family + patients + contacts
- `PUT /api/v1/families/{id}` — update family name/notes
- `GET /api/v1/patients/{id}` — patient + family + contacts + memories + agenda + reminders

## Repo secrets
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- `API_KEY` — value expected in header `x-api-key`
- `SQL_SERVER_FQDN` — e.g. `dementia-sql-xxxxx.database.windows.net`
- `SQL_DATABASE` — e.g. `dementia`

## Grant DB access
As Azure AD admin on the database, run:
CREATE USER [dementia-func] FROM EXTERNAL PROVIDER;
ALTER ROLE db_datareader ADD MEMBER [dementia-func];
ALTER ROLE db_datawriter ADD MEMBER [dementia-func];

(Use the Function App's managed identity name/object id after deployment.)

## Deploy
Push to `main`. The workflow will:
1) Create the Function App + Storage + App Insights (Bicep)
2) Zip-deploy the functions
3) Print URLs for Swagger
