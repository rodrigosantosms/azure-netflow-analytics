#!/usr/bin/env bash
set -euo pipefail

# Usage: ./deploy.sh <subscriptionId> <resourceGroup> <location>
SUB=${1:?subscription id}
RG=${2:?resource group}
LOC=${3:?location, e.g. eastus}

az account set --subscription "$SUB"

# Create RG
az group create -n "$RG" -l "$LOC"

# Deploy bicep
az deployment group create -g "$RG" -f ./infra/bicep/main.bicep -p location="$LOC"

echo ">>> NOTE: LA dedicated cluster linking can take up to ~2 hours. Data export will activate after link completes."
echo ">>> Next: assign 'Azure Event Hubs Data Receiver' role to the ADX cluster MSI on the EH namespace:"
echo "az role assignment create --assignee-object-id \"$(az resource show --ids $(az kusto cluster show -g $RG -n netflow-adx --query identity.principalId -o tsv) --query identity.principalId -o tsv)\" --assignee-principal-type ServicePrincipal --role 'Azure Event Hubs Data Receiver' --scope $(az eventhubs namespace show -g $RG -n netflow-ehns --query id -o tsv)"
