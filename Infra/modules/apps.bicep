param location string
param tags object
param environmentId string
param apiImage string
param frontendImage string
param dbHost string
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
        external: false // Internal only as requested
        targetPort: 5000 // Matches your Node.js code
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
        name: 'api'
        image: apiImage
        env: [
          { name: 'DB_HOST', value: dbHost }
          { name: 'AZURE_CLIENT_ID', value: managedIdentityClientId }
          { name: 'PORT', value: '5000' } // Explicitly tell the code to use 5000
          { 
            name: 'FRONTEND_URL' 
            value: 'https://aca-frontend.${location}.azurecontainerapps.io' // Needed for CORS in index.js
          }
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
          { 
            name: 'VITE_API_URL' // Prefix required for Vite to access it in the browser
            value: 'https://${apiApp.properties.configuration.ingress.fqdn}' // Internal URL of the backend
          }
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