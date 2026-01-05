param location string
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-3tier-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: { 
    sku: { 
      name: 'PerGB2018' 
    } 
    retentionInDays: 30
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-3tier'
  location: location
  tags: tags
  properties: {
    addressSpace: { 
      addressPrefixes: ['10.0.0.0/16'] 
    }
    subnets: [
      {
        name: 'snet-aca'
        properties: {
          addressPrefix: '10.0.0.0/23'
        }
      }
      {
        name: 'snet-db'
        properties: {
          addressPrefix: '10.0.2.0/24'
          delegations: [
            { 
              name: 'psql-delegation'
              properties: { 
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers' 
              } 
            }
          ]
        }
      }
    ]
  }
}

@description('The Resource ID of the Subnet for Container Apps')
output acaSubnetId string = vnet.properties.subnets[0].id

@description('The Resource ID of the Subnet for PostgreSQL')
output dbSubnetId string = vnet.properties.subnets[1].id

@description('The Resource ID of the Log Analytics Workspace')
output logAnalyticsWorkspaceId string = logAnalytics.id
