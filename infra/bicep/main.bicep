// main.bicep - deploy LA Dedicated Cluster + Workspace, Event Hub, ADX, Data Export, Container Apps env + ACR
targetScope = 'resourceGroup'

@description('Name prefix for all resources')
param namePrefix string = 'netflow'

@description('Location')
param location string = resourceGroup().location

@description('Log Analytics daily cap (GB). Leave empty to disable cap.')
@minLength(0)
param laDailyCap int = 0

@description('ADX sku capacity (Dev(No SLA)_Standard_D11_v2) or e.g., Standard_D14_v2')
param adxSku string = 'Standard_D11_v2'

@description('ADX instance capacity (instances)')
param adxInstances int = 2

@description('LA Dedicated cluster capacity (GB/day, min 100)')
param laClusterCapacity int = 100

@description('Enable Container Apps with internal ingress')
param enableContainerApps bool = true

@description('Container Apps environment internal only (true) or public (false)')
param containerAppsInternal bool = true

@description('GitHub repo URL for provenance')
param repoUrl string = 'https://github.com/your-org/azure-netflow-analytics'

// ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: '${namePrefix}acr'
  location: location
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: false }
}

// LA Dedicated Cluster
resource laCluster 'Microsoft.OperationalInsights/clusters@2025-02-01' = {
  name: '${namePrefix}-la-cluster'
  location: location
  sku: {
    name: 'capacityReservation'
    capacity: laClusterCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    isAvailabilityZonesEnabled: false
  }
}

// Log Analytics Workspace (no pricing tier), later linked to cluster
resource laWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  properties: {
    retentionInDays: 180
    features: {
      // clusterResourceId will appear after link operation completes
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: (
      laDailyCap > 0 ? {
        dailyQuotaGb: laDailyCap
      } : null
    )
  }
}

// Link Workspace -> Dedicated Cluster using linkedServices/cluster
resource linkToCluster 'Microsoft.OperationalInsights/workspaces/linkedServices@2020-08-01' = {
  name: 'cluster'
  parent: laWorkspace
  properties: {
    writeAccessResourceId: laCluster.id
  }
  dependsOn: [
    laCluster
    laWorkspace
  ]
}

// Event Hubs namespace (for data export LA -> EH -> ADX)
resource ehNs 'Microsoft.EventHub/namespaces@2024-01-01' = {
  name: '${namePrefix}-ehns'
  location: location
  sku: { name: 'Standard', tier: 'Standard' }
  properties: {
    isAutoInflateEnabled: true
    maximumThroughputUnits: 20
  }
}

resource ehNetflow 'Microsoft.EventHub/namespaces/eventhubs@2024-01-01' = {
  name: '${ehNs.name}/${namePrefix}-flows'
  properties: {
    messageRetentionInDays: 1
    partitionCount: 8
  }
}

// Data Export rule: export NSG Flow Logs table(s) from LA to Event Hubs
// NSG Flow Logs arrive in AzureNetworkAnalytics_CL (Traffic Analytics). Include also AzureDiagnostics if needed.
resource dataExport 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  name: 'export-flows'
  parent: laWorkspace
  properties: {
    destination: {
      resourceId: ehNs.id
    }
    tableNames: [
      'AzureNetworkAnalytics_CL'
    ]
    enable: true
  }
  dependsOn: [
    linkToCluster
    ehNs
  ]
}

// ADX Cluster + DB
resource adxCluster 'Microsoft.Kusto/clusters@2023-08-15' = {
  name: '${namePrefix}-adx'
  location: location
  sku: {
    name: 'Standard_D11_v2'
    tier: 'Standard'
    capacity: adxInstances
  }
  properties: {
    enableDiskEncryption: true
  }
}

resource adxDb 'Microsoft.Kusto/clusters/databases@2023-08-15' = {
  name: '${adxCluster.name}/${namePrefix}db'
  properties: {
    softDeletePeriod: '365.00:00:00'
    hotCachePeriod: '30.00:00:00'
  }
}

// Grant ADX cluster MSI access to EH (receiver) will be configured post-deploy via script

// ADX data connection from Event Hub
resource adxConn 'Microsoft.Kusto/clusters/databases/dataConnections@2023-08-15' = {
  name: '${adxDb.name}/ehconn'
  properties: {
    kind: 'EventHub'
    eventHubResourceId: ehNetflow.id
    consumerGroup: '$Default'
    dataFormat: 'multijson'
    tableName: 'FlowLogsRaw'
    mappingRuleName: 'FlowLogsRawMapping'
    compression: 'None'
  }
  dependsOn: [
    adxDb
    ehNetflow
  ]
}

// Container Apps environment + apps (images set later)
resource logAnalyticsForCAE 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: laWorkspace.name
}

resource cae 'Microsoft.App/managedEnvironments@2024-02-02-preview' = if (enableContainerApps) {
  name: '${namePrefix}-cae'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsForCAE.properties.customerId
        sharedKey: '***' // placeholder; recommend using environment secrets at deploy time
      }
    }
    vnetConfiguration: {
      internal: containerAppsInternal
    }
  }
}

// Output IDs
output workspaceId string = laWorkspace.id
output laClusterId string = laCluster.id
output eventHubId string = ehNetflow.id
output adxClusterId string = adxCluster.id
output adxDbName string = namePrefix + 'db'
