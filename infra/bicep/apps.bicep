// apps.bicep - deploy Container Apps for API and Web after images are built & pushed to ACR
targetScope = 'resourceGroup'

@description('Name prefix (must match main deploy)')
param namePrefix string = 'netflow'

@description('Location')
param location string = resourceGroup().location

@description('Container Apps Environment name (from main)')
param caeName string = '${namePrefix}-cae'

@description('Container Registry server (e.g., myacr.azurecr.io)')
param acrServer string

@description('API image tag (e.g., netflow/api:abcd123)')
param apiImage string

@description('WEB image tag (e.g., netflow/web:abcd123)')
param webImage string

@description('ADX URI (e.g., https://netflow-adx.eastus.kusto.windows.net)')
param adxUri string

@description('ADX database name')
param adxDb string = '${namePrefix}db'

@description('Allowed CORS origins (comma-separated)')
param corsOrigins string = '*'

@description('Tenant ID for Entra ID')
param tenantId string

@description('Public ingress for Web app?')
param webPublicIngress bool = true

resource cae 'Microsoft.App/managedEnvironments@2024-02-02-preview' existing = {
  name: caeName
}

resource apiApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: '${namePrefix}-api'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    environmentId: cae.id
    configuration: {
      registries: [
        {
          server: acrServer
          identity: 'system'
        }
      ]
      ingress: {
        external: false
        targetPort: 8080
      }
      secrets: []
      activeRevisionsMode: 'single'
    }
    template: {
      containers: [
        {
          image: '${acrServer}/${apiImage}'
          name: 'api'
          env: [
            { name: 'ADX_URI', value: adxUri },
            { name: 'ADX_DB', value: adxDb },
            { name: 'CORS_ORIGINS', value: corsOrigins },
            { name: 'ENTRA_TENANT_ID', value: tenantId }
          ]
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
      scale: { minReplicas: 2, maxReplicas: 10 }
    }
  }
}

resource webApp 'Microsoft.App/containerApps@2024-02-02-preview' = {
  name: '${namePrefix}-web'
  location: location
  identity: { type: 'SystemAssigned' }
  properties: {
    environmentId: cae.id
    configuration: {
      registries: [
        { server: acrServer, identity: 'system' }
      ]
      ingress: {
        external: webPublicIngress
        targetPort: 3000
      }
      secrets: []
      activeRevisionsMode: 'single'
    }
    template: {
      containers: [
        {
          image: '${acrServer}/${webImage}'
          name: 'web'
          env: [
            { name: 'NEXT_PUBLIC_API_BASE', value: 'http://netflow-api:8080' }
          ]
          resources: { cpu: 1, memory: '1Gi' }
        }
      ]
      scale: { minReplicas: 2, maxReplicas: 10 }
    }
  }
  dependsOn: [ apiApp ]
}
