targetScope = 'resourceGroup'

param location string = resourceGroup().location
param dbAdminLogin string = 'psqladmin'

@secure()
param dbAdminPassword string

// Parameters to catch values from the pipeline or defaults
param dbUser string = 'psqladmin'
@secure()
param dbPassword string

@secure()
param acrPassword string = ''

// Updated to point to your specific ACR by default
param apiImage string = 'acr3tierfylxnlaj2ey4a.azurecr.io/todo-backend:latest'
param frontendImage string = 'acr3tierfylxnlaj2ey4a.azurecr.io/todo-frontend:latest'

var commonTags = resourceGroup().tags

module network './modules/network.bicep' = {
  name: 'network-module'
  params: {
    location: location
    tags: commonTags
  }
}

module security './modules/security.bicep' = {
  name: 'security-module'
  params: {
    location: location
    tags: commonTags
    // NEW: Pass the password to security module so it can be stored in Key Vault
    dbPassword: dbPassword 
  }
}

module registry './modules/registry.bicep' = {
  name: 'registry-module'
  params: {
    location: location
    tags: commonTags
  }
}

module database './modules/database.bicep' = {
  name: 'database-module'
  params: {
    location: location
    tags: commonTags
    dbSubnetId: network.outputs.dbSubnetId
    dbAdminLogin: dbAdminLogin
    dbAdminPassword: dbAdminPassword
  }
}

module environment './modules/environment.bicep' = {
  name: 'environment-module'
  params: {
    location: location
    tags: commonTags
    acaSubnetId: network.outputs.acaSubnetId
    logWorkspaceId: network.outputs.logAnalyticsWorkspaceId
  }
}

module apps './modules/apps.bicep' = {
  name: 'apps-module'
  params: {
    location: location
    tags: commonTags
    environmentId: environment.outputs.environmentId
    apiImage: apiImage
    frontendImage: frontendImage
    dbHost: database.outputs.psqlHost
    dbUser: dbUser
    // FIXED: Instead of raw dbPassword, we pass the secure Secret URI from Key Vault
    dbSecretUri: security.outputs.dbSecretUri 
    managedIdentityId: security.outputs.identityId
    managedIdentityClientId: security.outputs.identityClientId
    acrName: registry.outputs.acrName 
    acrUserName: registry.outputs.acrUserName
    acrPassword: registry.outputs.acrPassword 
  }
}