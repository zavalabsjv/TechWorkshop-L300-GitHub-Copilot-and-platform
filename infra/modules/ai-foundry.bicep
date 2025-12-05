// AI Foundry (Azure AI Studio) workspace

@description('Name of the AI Foundry workspace')
param name string

@description('Location for the AI Foundry workspace')
param location string

@description('Tags to apply to the resource')
param tags object = {}

@description('Storage account name for AI Foundry')
param storageAccountName string = 'staif${uniqueString(resourceGroup().id)}'

@description('Key Vault name for AI Foundry')
param keyVaultName string = 'kv-aif-${uniqueString(resourceGroup().id)}'

// Storage Account for AI Foundry
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// Key Vault for AI Foundry
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    publicNetworkAccess: 'Enabled'
  }
}

// AI Services Account (Cognitive Services multi-service account)
resource aiServices 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: 'ais-${name}'
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: 'ais-${uniqueString(resourceGroup().id)}'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// AI Foundry Hub (formerly Azure AI Studio Hub)
resource aiFoundryHub 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: name
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    publicNetworkAccess: 'Enabled'
  }
}

// AI Foundry Project (separate resource)
resource aiFoundryProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: '${take(name, 24)}-proj'
  location: location
  tags: tags
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    friendlyName: '${name} Project'
    hubResourceId: aiFoundryHub.id
    publicNetworkAccess: 'Enabled'
  }
}

// AI Services connection to AI Foundry
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01' = {
  name: 'aiservices-connection'
  parent: aiFoundryHub
  properties: {
    category: 'AIServices'
    target: aiServices.properties.endpoint
    authType: 'ApiKey'
    isSharedToAll: true
    credentials: {
      key: aiServices.listKeys().key1
    }
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServices.id
    }
  }
}

output id string = aiFoundryHub.id
output name string = aiFoundryHub.name
output endpoint string = aiServices.properties.endpoint
output projectId string = aiFoundryProject.id
output projectName string = aiFoundryProject.name
output aiServicesEndpoint string = aiServices.properties.endpoint
