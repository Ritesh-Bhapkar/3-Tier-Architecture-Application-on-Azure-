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
  name: 'kv5t-v3-${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    // CHANGED: Set to false to use Access Policies instead of RBAC roles
    enableRbacAuthorization: false 
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: identity.properties.principalId // Gives access to the Managed Identity
        permissions: {
          secrets: [ 'get', 'list' ] // Permission to read the password
        }
      }
    ]
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

// REMOVED: The kvRoleAssignment block is gone because it requires Admin/Owner rights.

// Outputs for your apps.bicep and main.bicep
output identityId string = identity.id
output identityClientId string = identity.properties.clientId
output kvName string = kv.name
output dbSecretUri string = dbSecret.properties.secretUri