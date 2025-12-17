param location string
param tags object
param environmentId string
param apiImage string
param frontendImage string
param dbHost string
param managedIdentityId string
param managedIdentityClientId string
param acrName string
param acrUserName string // New: ACR Admin Username
@secure()
param acrPassword string // New: ACR Admin Password

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
      activeRevisionsMode: 'Single'
      ingress: { 
        external: false 
        targetPort: 8080 
        transport: 'auto'
      }
      // Store ACR password as a secret in ACA
      secrets: [
        {
          name: 'acr-password'
          value: acrPassword
        }
      ]
      // Use credentials instead of Identity to bypass permission issues
      registries: [
        {
          server: '${acrName}.azurecr.io'
          username: acrUserName
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      containers: [{
        name: 'api'
        image: apiImage
        env: [
          { name: 'DB_HOST', value: dbHost }
          { name: 'AZURE_CLIENT_ID', value: managedIdentityClientId }
        ]
        resources: {
          cpu: json('0.25')
          memory: '0.5Gi'
        }
      }]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}

resource frontendApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'aca-frontend'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: { 
        external: true 
        targetPort: 80 
        transport: 'auto'
      }
      secrets: [
        {
          name: 'acr-password'
          value: acrPassword
        }
      ]
      registries: [
        {
          server: '${acrName}.azurecr.io'
          username: acrUserName
          passwordSecretRef: 'acr-password'
        }
      ]
    }
    template: {
      containers: [{
        name: 'frontend'
        image: frontendImage
        env: [
          { name: 'API_URL', value: 'https://${apiApp.properties.configuration.ingress.fqdn}' }
        ]
        resources: {
          cpu: json('0.25')
          memory: '0.5Gi'
        }
      }]
      scale: {
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}
