targetScope = 'resourceGroup'

param location string = resourceGroup().location
param dbAdminLogin string = 'psqladmin'

@secure()
param dbAdminPassword string

// FIXED: Parameters to catch values from the pipeline
param dbUser string = 'psqladmin'
@secure()
param dbPassword string
@secure()
param acrPassword string 

// UPDATED: Pointing to your ACR by default instead of Hello World
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
    dbPassword: dbPassword
    managedIdentityId: security.outputs.identityId
    managedIdentityClientId: security.outputs.identityClientId
    acrName: registry.outputs.acrName 
    acrUserName: registry.outputs.acrUserName
    acrPassword: acrPassword 
  }
}