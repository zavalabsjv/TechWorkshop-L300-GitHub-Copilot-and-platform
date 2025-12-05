// App Service Plan (Linux)

@description('Name of the App Service Plan')
param name string

@description('Location for the App Service Plan')
param location string

@description('Tags to apply to the resource')
param tags object = {}

@description('SKU for the App Service Plan')
@allowed([
  'F1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1v2'
  'P2v2'
  'P3v2'
])
param sku string = 'F1'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux
    zoneRedundant: false
  }
}

output id string = appServicePlan.id
output name string = appServicePlan.name
