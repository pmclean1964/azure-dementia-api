Architecture Decision: Bicep vs PowerShell for Infrastructure

Context
- This project currently provisions its minimal Azure resources (Function App, Storage Account, app settings) via a PowerShell script using Azure CLI (infrastructure/deploy.ps1).
- We also need to retrieve database connection information from an existing Key Vault (dementiadbsecrets) and set the values as Function App application settings.

Options
1) Continue with PowerShell (Azure CLI)
   Pros
   - Fast to iterate and easy to run locally or in CI.
   - Simple for small, evolving setups.
   - No additional language/templating to learn beyond CLI commands.
   Cons
   - Imperative and less declarative/idempotent than templates.
   - Harder to scale as the infrastructure grows and cross‑resource dependencies increase.

2) Adopt Bicep (ARM template language)
   Pros
   - Declarative IaC with strong typing, validation, and what-if deployments.
   - Repeatable, idempotent deployments ideal for multiple environments.
   - Native to Azure; easy parameterization and modularization.
   Cons
   - Initial time investment to author templates and pipelines.
   - Slightly higher barrier for quick ad‑hoc changes.

Decision
- For the current scope (a minimal Function App and related settings), we will continue using the PowerShell script for speed and simplicity.
- We will revisit adopting Bicep when any of the following triggers occur:
  - Additional resources are introduced (e.g., VNet, private endpoints, Application Insights, API Management, private DNS).
  - Multiple environments (dev/test/stage/prod) require consistent, parameterized deployments.
  - Compliance or team practices require fully declarative IaC.

Consequences
- Keep infrastructure/deploy.ps1 as the primary deployment entry point.
- Ensure the script remains idempotent where practical and includes clear parameters and logging.
- When expanding infrastructure, plan a migration path to Bicep (or Terraform) with:
  - A resource group–scoped main.bicep
  - Parameter files per environment
  - CI/CD pipeline steps using az deployment group/sub what-if and deploy

Status
- Accepted (for current phase)

Date
- 2025-10-07
