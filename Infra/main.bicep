targetScope = 'resourceGroup'

param location string = resourceGroup().location
param dbAdminLogin string = 'psqladmin'

@secure()
param dbAdminPassword string

// Parameters to catch values from the pipeline or defaults
param dbUser string = 'psqladmin'
@secure()
param dbPassword string

// FIXED: Using the fully qualified resource ID for Diagnostic Settings
param workspaceId string = '/subscriptions/aca42f90-33f4-4476-875d-feb34fe201cb/resourceGroups/gbp-devops-ritesh/providers/Microsoft.OperationalInsights/workspaces/log-3tier-fylxnlaj2ey4a'

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
    // Passing the full resource ID to the module
    workspaceId: workspaceId 
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
    dbSecretUri: security.outputs.dbSecretUri 
    managedIdentityId: security.outputs.identityId
    managedIdentityClientId: security.outputs.identityClientId
    acrName: registry.outputs.acrName 
    acrUserName: registry.outputs.acrUserName
    acrPassword: registry.outputs.acrPassword 
    // ADDED: Passing the action group ID from database module to apps module
    actionGroupId: database.outputs.actionGroupId
  }
}