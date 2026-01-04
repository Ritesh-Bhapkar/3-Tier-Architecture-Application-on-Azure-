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
param actionGroupId string 
param logAnalyticsWorkspaceName string 

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'app-insights-3tier'
  tags: tags
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: resourceId('Microsoft.OperationalInsights/workspaces', logAnalyticsWorkspaceName)
  }
}

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
        { name: 'db-password', keyVaultUrl: dbSecretUri, identity: managedIdentityId }
      ]
      registries: [
        { server: '${acrName}.azurecr.io', username: acrUserName, passwordSecretRef: 'acr-password' }
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
          { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
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
      ingress: { external: true, targetPort: 80, transport: 'http' }
      secrets: [{ name: 'acr-password', value: acrPassword }]
      registries: [
        { server: '${acrName}.azurecr.io', username: acrUserName, passwordSecretRef: 'acr-password' }
      ]
    }
    template: {
      containers: [{
        name: 'frontend'
        image: frontendImage
        env: [
          { name: 'VITE_API_URL', value: '/api' }
          { name: 'VITE_APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsights.properties.ConnectionString }
        ]
        resources: { cpu: json('0.25'), memory: '0.5Gi' }
      }]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
}

resource apiErrorAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-api-5xx-errors'
  tags: tags
  location: 'global'
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
          timeAggregation: 'Total'
          dimensions: [{ name: 'StatusCode', operator: 'Include', values: [ '5xx' ] }]
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

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
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

resource frontendHighTrafficAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-frontend-high-traffic'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when frontend receives more than 50 requests in 1 minute'
    severity: 2
    enabled: true
    scopes: [ frontendApp.id ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT1M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighTraffic'
          metricName: 'Requests'
          operator: 'GreaterThan'
          threshold: 50
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

resource availabilityTest 'Microsoft.Insights/webtests@2022-06-15' = {
  name: 'Bengaluru-to-US-Check'
  location: location
  tags: union(tags, {
    'hidden-link:${appInsights.id}': 'Resource'
  })
  kind: 'standard'
  properties: {
    Name: 'Bengaluru-to-US-Check'
    Enabled: true
    Frequency: 300
    Timeout: 120
    Kind: 'standard'
    RetryEnabled: true
    Locations: [
      { Id: 'us-ca-sjc-azr' }    
      { Id: 'emea-nl-ams-azr' }      
      { Id: 'apac-sg-sin-azr' }    
    ]
    Request: {
      RequestUrl: 'https://${frontendApp.properties.configuration.ingress.fqdn}'
      HttpVerb: 'GET'
      ParseDependentRequests: false
    }
    ValidationRules: {
      ExpectedHttpStatusCode: 200
      SSLCheck: true
      SSLCertRemainingLifetimeCheck: 7
    }
  }
}

resource globalAvailabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-global-availability'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert if site is unreachable from more than 1 global location'
    severity: 1
    enabled: true
    scopes: [ availabilityTest.id, appInsights.id ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'AvailabilityFail'
          metricName: 'availabilityResults/availabilityPercentage'
          operator: 'LessThan'
          threshold: 90
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}

resource dbConnectionAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-db-connection-failure'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert if API cannot communicate with the Database'
    severity: 0 
    enabled: true
    scopes: [ appInsights.id ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'DbFailures'
          metricName: 'dependencies/failed'
          operator: 'GreaterThan'
          threshold: 0
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [{ actionGroupId: actionGroupId }]
  }
}