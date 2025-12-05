// AI Foundry (Azure AI Studio) workspace
// This module enforces identity-only authentication with no API keys

@description('Name of the AI Foundry workspace')
param name string

@description('Location for the AI Foundry workspace')
param location string

@description('Principal ID of the managed identity for RBAC role assignment')
param managedIdentityPrincipalId string

@description('Log Analytics Workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string

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
// Note: Connection is created for Hub workspace visibility
// Actual authentication uses managed identity via RBAC role assignment
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01' = {
  name: 'aiservices-connection'
  parent: aiFoundryHub
  properties: {
    category: 'AIServices'
    target: aiServices.properties.endpoint
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServices.id
    }
  }
}

// RBAC Role Assignment: Grant "Cognitive Services User" to managed identity on AI Services resource
// This is required for identity-only authentication to work
resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, managedIdentityPrincipalId, 'a97b65f3-24c9-4844-a930-0ef25a3225ec')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c9-4844-a930-0ef25a3225ec')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Diagnostic Settings for AI Services (Cognitive Services)
// Sends all diagnostic logs and metrics to Log Analytics Workspace
resource aiServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${aiServices.name}'
  scope: aiServices
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Note: AI Foundry Hub workspace diagnostic settings are limited
// Most detailed diagnostics are captured at the AI Services (Cognitive Services) level
// Hub-level metrics are available but detailed event logs require Azure AI Services level diagnostics

// Note: AI Foundry Project workspace diagnostic settings are limited
// Most detailed diagnostics are captured at the AI Services (Cognitive Services) level

output id string = aiFoundryHub.id
output name string = aiFoundryHub.name
output endpoint string = aiServices.properties.endpoint
output projectId string = aiFoundryProject.id
output projectName string = aiFoundryProject.name
output aiServicesEndpoint string = aiServices.properties.endpoint
