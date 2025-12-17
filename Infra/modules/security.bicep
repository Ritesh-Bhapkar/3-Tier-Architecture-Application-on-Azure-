param location string
param tags object

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-3tier-api'
  location: location
  tags: tags
}

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv4t-v2-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
  }
}

// These two lines are what fix the errors in your main.bicep
output identityId string = identity.id
output identityClientId string = identity.properties.clientId
output kvName string = kv.name
