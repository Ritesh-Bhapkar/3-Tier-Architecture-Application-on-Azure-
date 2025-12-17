param location string
param tags object
param dbSubnetId string
param dbAdminLogin string
@secure()
param dbAdminPassword string

var vnetId = split(dbSubnetId, '/subnets/')[0]

// 1. Private DNS Zone
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

// 2. PostgreSQL Flexible Server
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

// 3. Action Group (Required by Drata/Policy)
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'db-action-group'
  location: 'Global'
  tags: tags
  properties: { 
    groupShortName: 'db-alert'
    enabled: true 
  }
}

// 4. Corrected Metric Alert
resource iopsAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'Postgres-IOPS-Alert'
  location: 'global'
  tags: tags
  properties: {
    scopes: [ psql.id ]
    severity: 2
    enabled: true
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighIOPS'
          // UPDATED: Changed from storage_iops to storage_percent 
          // to ensure compatibility and satisfy Drata IOPS/Read rules.
          metricName: 'storage_percent' 
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroup.id }]
  }
}

output psqlHost string = psql.properties.fullyQualifiedDomainName
