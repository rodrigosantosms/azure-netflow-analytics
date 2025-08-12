# Azure NetFlow Analytics (Better-than-TA)

An Azure-native, high-performance Top Talkers and Network Flow Analytics portal.
- **System of record**: Log Analytics Workspace on a **Dedicated Cluster**
- **Interactive analytics**: Azure Data Explorer (ADX) with materialized views
- **Web**: Next.js (TypeScript) + .NET 8 minimal API
- **Hosting**: Azure Container Apps, private networking, Entra ID

## Quick start (high level)
1. Create a resource group and ACR.
2. Deploy infra with Bicep (`infra/scripts/deploy.sh` or `.ps1`).
3. (Optional) Seed sample data to ADX (`tools/seed`).
4. Build & push images via GitHub Actions (`.github/workflows/build-deploy.yml`).
5. Browse the portal (Front Door/AppGW URL or Container Apps internal).

> Detailed instructions live in `infra/scripts/README-INSTALL.md`.
