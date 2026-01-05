param location string = resourceGroup().location
param tags object = {}
param dbSubnetId string
param dbAdminLogin string
@secure()
param dbAdminPassword string
param workspaceId string 

var vnetId = split(dbSubnetId, '/subnets/')[0]

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${uniqueString(resourceGroup().id)}.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

resource dnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: 'db-vnet-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

resource psql 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: 'psql-3tier-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: { 
    name: 'Standard_B1ms'
    tier: 'Burstable' 
  }
  properties: {
    administratorLogin: dbAdminLogin
    administratorLoginPassword: dbAdminPassword
    version: '15'
    storage: { storageSizeGB: 32 }
    network: { 
      delegatedSubnetResourceId: dbSubnetId
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
  }
  dependsOn: [ dnsVnetLink ]
}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'db-action-group'
  location: 'Global'
  tags: tags
  properties: { 
    groupShortName: 'db-alert'
    enabled: true
    emailReceivers:[
      {
        name: 'RiteshEmail'
        emailAddress: 'ritesh.bhapkar@costrategix.com'
        useCommonAlertSchema: true
      }
    ]
  }
}

// 4. Metric Alert (Updated for Read IOPS)
resource iopsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Postgres-Read-IOPS-Alert'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when Database Read IOPS are high'
    scopes: [ psql.id ]
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighReadIOPS'
          metricName: 'read_iops' 
          operator: 'GreaterThan'
          threshold: 1 
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

resource dbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'db-diagnostic-logs'
  scope: psql
  properties: {
    workspaceId: workspaceId
    logs: [ { category: 'PostgreSQLLogs', enabled: true } ]
    metrics: [ { category: 'AllMetrics', enabled: true } ]
  }
}

output psqlHost string = psql.properties.fullyQualifiedDomainName
output actionGroupId string = actionGroup.id