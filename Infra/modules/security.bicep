param location string
param tags object

// The password passed from your main.bicep
@secure()
param dbPassword string 

// 1. Create the User-Assigned Managed Identity (The "ID Card")
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-3tier-api'
  location: location
  tags: tags
}

// 2. Create the Key Vault (The "Digital Safe")
resource kv 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv5t-v2-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // MUST be true for the role assignment below to work
  }
}

// 3. Store the Database Password inside the Key Vault as a Secret
resource dbSecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  parent: kv
  name: 'db-password'
  properties: {
    value: dbPassword
  }
}

// 4. Assign the "Key Vault Secrets User" role to your Managed Identity
// This specific GUID (4633458b...) is the official Azure ID for secret reading permissions
var secretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, identity.id, secretsUserRoleId)
  scope: kv
  properties: {
    principalId: identity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', secretsUserRoleId)
    principalType: 'ServicePrincipal'
  }
}

// Outputs for your apps.bicep and main.bicep
output identityId string = identity.id
output identityClientId string = identity.properties.clientId
output kvName string = kv.name
output dbSecretUri string = dbSecret.properties.secretUri