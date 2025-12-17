param location string
param tags object
param environmentId string
param apiImage string
param frontendImage string
param dbHost string
param managedIdentityId string
param managedIdentityClientId string

resource apiApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'aca-api'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: { external: false, targetPort: 8080 }
    }
    template: {
      containers: [{
        name: 'api'
        image: apiImage
        env: [
          { name: 'DB_HOST', value: dbHost }
          { name: 'AZURE_CLIENT_ID', value: managedIdentityClientId }
        ]
      }]
    }
  }
}

resource frontendApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'aca-frontend'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: { external: true, targetPort: 80 }
    }
    template: {
      containers: [{
        name: 'frontend'
        image: frontendImage
        env: [{ name: 'API_URL', value: 'https://${apiApp.properties.configuration.ingress.fqdn}' }]
      }]
    }
  }
}
