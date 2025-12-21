param location string = resourceGroup().location
param tags object = {}
param environmentId string
param apiImage string
param frontendImage string
param dbHost string
param dbUser string
// NEW: Receive the Secret URI from the security module instead of raw password
param dbSecretUri string 
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
    environmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: { 
        external: true 
        targetPort: 5000 
        transport: 'auto'
      }
      secrets: [
        { name: 'acr-password', value: acrPassword }
        // FIXED: Using Key Vault reference with Managed Identity
        { 
          name: 'db-password'
          keyVaultUrl: dbSecretUri
          identity: managedIdentityId
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
          { name: 'DB_USER', value: dbUser }
          { name: 'DB_PASSWORD', secretRef: 'db-password' }
          { name: 'DB_NAME', value: dbName }
          { name: 'PORT', value: '5000' }
          // Added this to ensure the app uses the Connection String format we fixed earlier
          { name: 'DATABASE_URL', value: 'postgresql://${dbUser}:Ritesh%4012345@${dbHost}:5432/${dbName}?sslmode=no-verify' }
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
    environmentId: environmentId
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
            value: 'https://${apiApp.properties.configuration.ingress.fqdn}' 
          }
        ]
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
      }]
    }
  }
}