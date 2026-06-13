param location string
param tags object
param acaSubnetId string
param logWorkspaceId string

resource acaEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'aca-env-3tier'
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      internal: false
      infrastructureSubnetId: acaSubnetId
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logWorkspaceId, '2022-10-01').customerId
        sharedKey: listKeys(logWorkspaceId, '2022-10-01').primarySharedKey
      }
    }
  }
}

output environmentId string = acaEnv.id
