param location string = resourceGroup().location
param tags object = {}
param environmentId string
param apiImage string
param frontendImage string
param dbHost string
// Automated DB Params
param dbUser string
@secure()
param dbPassword string
param dbName string = 'postgres'

param managedIdentityId string
param managedIdentityClientId string
param acrName string
param acrUserName string 
@secure()
param acrPassword string 

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
        targetPort: 5000 
        transport: 'auto'
      }
      secrets: [
        { name: 'acr-password', value: acrPassword }
        { name: 'db-password', value: dbPassword }
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
        name: 'api'
        image: apiImage
        env: [
          { name: 'DB_HOST', value: dbHost }
          { name: 'DB_USER', value: dbUser }
          { name: 'DB_PASSWORD', secretRef: 'db-password' }
          { name: 'DB_NAME', value: dbName }
          { name: 'PORT', value: '5000' }
          { name: 'FRONTEND_URL', value: 'https://aca-frontend.${location}.azurecontainerapps.io' }
        ]
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
      }]
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
      ingress: { external: true, targetPort: 80, transport: 'auto' }
      secrets: [{ name: 'acr-password', value: acrPassword }]
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
          { 
            name: 'VITE_API_URL' 
            // AUTOMATION: Grabs internal FQDN + Port automatically
            value: 'https://${apiApp.properties.configuration.ingress.fqdn}:5000' 
          }
        ]
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
      }]
    }
  }
}