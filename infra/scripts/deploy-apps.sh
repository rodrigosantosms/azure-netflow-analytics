#!/usr/bin/env bash
set -euo pipefail
# Usage: ./deploy-apps.sh <subId> <rg> <acrServer> <apiImage> <webImage> <adxUri> <adxDb> <tenantId> [location]
SUB=${1:?}
RG=${2:?}
ACR=${3:?}             # e.g., myacr.azurecr.io
API_IMG=${4:?}         # e.g., netflow/api:abcd123
WEB_IMG=${5:?}         # e.g., netflow/web:abcd123
ADX_URI=${6:?}
ADX_DB=${7:?}
TENANT=${8:?}
LOC=${9:-$(az group show -n $RG --query location -o tsv)}

az account set --subscription "$SUB"
az deployment group create -g "$RG" -f ./infra/bicep/apps.bicep -p location="$LOC" acrServer="$ACR" apiImage="$API_IMG" webImage="$WEB_IMG" adxUri="$ADX_URI" adxDb="$ADX_DB" tenantId="$TENANT"
