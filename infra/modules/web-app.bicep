// Web App (Linux container-based)

@description('Name of the Web App')
param name string

@description('Location for the Web App')
param location string

@description('App Service Plan ID')
param appServicePlanId string

@description('Managed Identity resource ID')
param managedIdentityId string

@description('Container Registry login server')
param containerRegistryLoginServer string

@description('Application Insights connection string')
@secure()
param applicationInsightsConnectionString string

@description('Application Insights instrumentation key')
@secure()
param applicationInsightsInstrumentationKey string

@description('AI Foundry endpoint')
param aiFoundryEndpoint string

@description('AI Foundry project ID')
param aiFoundryProjectId string

@description('Tags to apply to the resource')
param tags object = {}

@description('Docker image name')
param dockerImageName string = 'mcr.microsoft.com/appsvc/staticsite:latest' // Placeholder image

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: name
  location: location
  tags: tags
  kind: 'app,linux,container'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      linuxFxVersion: 'DOCKER|${dockerImageName}'
      alwaysOn: false  // Must be false for Free tier
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: split(managedIdentityId, '/')[8] // Extract client ID from resource ID
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistryLoginServer}'
        }
        {
          name: 'DOCKER_ENABLE_CI'
          value: 'true'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'recommended'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsInstrumentationKey
        }
        {
          name: 'AI_FOUNDRY_ENDPOINT'
          value: aiFoundryEndpoint
        }
        {
          name: 'AI_FOUNDRY_PROJECT_ID'
          value: aiFoundryProjectId
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Development'
        }
      ]
    }
  }
}

output id string = webApp.id
output name string = webApp.name
output url string = 'https://${webApp.properties.defaultHostName}'
output defaultHostName string = webApp.properties.defaultHostName
