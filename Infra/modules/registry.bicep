param location string
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: 'acr3tier${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true 
  }
}

output acrLoginServer string = acr.properties.loginServer
output acrName string = acr.name

// Added these outputs to provide credentials to the apps module
output acrUserName string = acr.listCredentials().username
output acrPassword string = acr.listCredentials().passwords[0].value
