param location string = resourceGroup().location
param tags object = {}
param environmentId string
param apiImage string
param frontendImage string
param dbHost string
param dbUser string
param dbSecretUri string 
param dbName string = 'postgres'
param managedIdentityId string
param managedIdentityClientId string 
param acrName string
param acrUserName string 
@secure()
param acrPassword string 
param actionGroupId string // <--- NEW PARAMETER

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
        external: false      
        targetPort: 5000 
        transport: 'http'    
        allowInsecure: true  
      }
      secrets: [
        { name: 'acr-password', value: acrPassword }
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
          { name: 'DATABASE_URL', value: 'postgresql://${dbUser}:Ritesh%4012345@${dbHost}:5432/${dbName}?sslmode=no-verify' }
        ]
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
      }]
      scale: { minReplicas: 1, maxReplicas: 1 }
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
      ingress: { 
        external: true 
        targetPort: 80 
        transport: 'http' 
      }
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
        env: [{ name: 'VITE_API_URL', value: '/api' }]
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
      }]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
}

// --- NEW APP LEVEL ALERTS ---

// Alert 1: High Error Rate (5xx)
resource apiErrorAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-api-5xx-errors'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when API returns 5xx errors'
    severity: 1
    enabled: true
    scopes: [ apiApp.id ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'High5xx'
          metricName: 'Requests'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Count'
          dimensions: [{ name: 'StatusCode', operator: 'Include', values: [ '5xx' ] }]
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

// Alert 2: High Latency (Slow Response)
resource apiLatencyAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-api-latency'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when API response time is > 1.5s'
    severity: 2
    enabled: true
    scopes: [ apiApp.id ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'SlowResponse'
          metricName: 'ResponseTime'
          operator: 'GreaterThan'
          threshold: 1500
          timeAggregation: 'Average'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}