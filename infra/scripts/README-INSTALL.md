# Install & Configure

## Prereqs
- Azure CLI >= 2.60
- Bicep CLI
- Permissions: Owner on RG scope
- GitHub repo with secrets set (see below)

## Steps
1. `az login`
2. `./infra/scripts/deploy.sh <subId> <rg> <location>`
3. Wait for **workspace link to dedicated cluster** to finish (can be ~90-120 minutes). See docs for status and limits.
4. Run KQL in the ADX database (portal or az kusto) from `infra/kusto/flow-schema.kql` to create tables and materialized views.
5. (Optional) Seed demo data: `dotnet run --project tools/seed`.
6. Push repo to GitHub; pipeline builds & deploys container apps.

## GitHub secrets required
- `AZURE_CREDENTIALS` (JSON from `az ad sp create-for-rbac --sdk-auth`)
- `AZ_SUBSCRIPTION_ID`
- `AZ_RESOURCE_GROUP`
- `AZ_LOCATION`
- `ACR_NAME` (from deployment output)
- `ADX_URI` (e.g. https://netflow-adx.<region>.kusto.windows.net)
- `ADX_DB`
- `API_ENTRA_CLIENT_ID`, `WEB_ENTRA_CLIENT_ID`, `ENTRA_TENANT_ID`
