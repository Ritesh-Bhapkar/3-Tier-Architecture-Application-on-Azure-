param location string
param tags object

@secure()
param dbPassword string 

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-3tier-api'
  location: location
  tags: tags
}

resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv5t-v3-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: false 
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: identity.properties.principalId 
        permissions: {
          secrets: [ 'get', 'list' ] 
        }
      }
    ]
  }
}

resource dbSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'db-password'
  properties: {
    value: dbPassword
  }
}


output identityId string = identity.id
output identityClientId string = identity.properties.clientId
output kvName string = kv.name
output dbSecretUri string = dbSecret.properties.secretUri