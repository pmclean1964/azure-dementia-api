# Azure App Service Express API (Node 20)

A minimal, production-ready skeleton for an Express API hosted on Azure App Service (Linux), deployed via GitHub Actions using OIDC (no publish profiles).

## Requirements / Assumptions
- Azure subscription
- GitHub OIDC federated credentials configured for this repo
- Repo secrets configured with these exact names:
  - AZURE_CLIENT_ID
  - AZURE_TENANT_ID
  - AZURE_SUBSCRIPTION_ID
  - AZURE_RESOURCE_GROUP
  - AZURE_WEBAPP_NAME
  - AZURE_LOCATION

## Repo Layout
```
/ (repo root)
├─ api/
│  ├─ server.js
│  └─ package.json
├─ infra/
│  └─ main.bicep
├─ .github/
│  └─ workflows/
│     └─ deploy-appservice.yml
├─ .gitignore
└─ README.md
```

## Local Development
Run the API locally using Node 20.

```
cd api
npm install
npm start
# visit http://localhost:3000/api/hello
```

Notes:
- Server binds to process.env.PORT if set; defaults to 3000 locally.
- Endpoints:
  - GET /api/hello → { "message": "hello world" }
  - GET /healthz → { "status": "ok" }

## CI/CD (GitHub Actions → Azure App Service)
- Triggered on push to main and manual workflow_dispatch.
- Uses azure/login with OIDC (id-token: write, no publish profile).
- Ensures the resource group exists.
- Deploys infra via Bicep (idempotent):
  - Linux App Service Plan
  - Linux Web App configured for Node 20
  - App settings for Node and Kudu build
- Installs Node 20, runs `npm ci` inside api/, zips contents to app.zip, and deploys zip to App Service using azure/webapps-deploy.

## Infra customization
- App Service Plan SKU: Change the `sku` parameter default in infra/main.bicep or override via the workflow `--parameters` as needed.
- Web App name: Provided by the secret AZURE_WEBAPP_NAME and passed to the Bicep deployment as the `name` parameter.
- Location: Provided by AZURE_LOCATION.

To change SKU at deployment time, you could extend the workflow step like:
```
az deployment group create \
  -g "$AZURE_RESOURCE_GROUP" \
  --template-file infra/main.bicep \
  --parameters name="$AZURE_WEBAPP_NAME" location="$AZURE_LOCATION" sku="S1"
```

## Production notes
- CORS is enabled globally; restrict origins for production.
- Health endpoint `/healthz` is suitable for liveness/readiness.
- App is set to Always On and HTTPS-only via Bicep.

## Checklist
Commit & push → Actions should provision and deploy. Visit: https://<webapp>.azurewebsites.net/api/hello
