// Main infrastructure deployment for ZavaStorefront
// This template orchestrates the deployment of all required Azure resources

targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment (e.g., dev, test, prod)')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = 'westus3'

@description('Unique suffix for resource naming')
param resourceToken string = uniqueString(subscription().id, environmentName, location)

@description('Tags to apply to all resources')
param tags object = {
  Environment: environmentName
  Application: 'ZavaStorefront'
  ManagedBy: 'AzureDeveloperCLI'
}

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-zavastorefront-${environmentName}-${location}'
  location: location
  tags: tags
}

// Managed Identity for App Service
module managedIdentity 'modules/managed-identity.bicep' = {
  name: 'managed-identity-deployment'
  scope: rg
  params: {
    name: 'id-zavastorefront-${environmentName}-${location}'
    location: location
    tags: tags
  }
}

// Monitoring (Log Analytics + Application Insights)
module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  scope: rg
  params: {
    location: location
    environmentName: environmentName
    tags: tags
  }
}

// Azure Container Registry
module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry-deployment'
  scope: rg
  params: {
    name: 'acrzavastore${resourceToken}'
    location: location
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    tags: tags
  }
}

// AI Foundry (Azure AI Studio)
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    name: 'aif-zavastorefront-${environmentName}-${location}'
    location: location
    tags: tags
  }
}

// App Service Plan
module appServicePlan 'modules/app-service-plan.bicep' = {
  name: 'app-service-plan-deployment'
  scope: rg
  params: {
    name: 'asp-zavastorefront-${environmentName}-${location}'
    location: location
    tags: tags
  }
}

// Web App
module webApp 'modules/web-app.bicep' = {
  name: 'web-app-deployment'
  scope: rg
  params: {
    name: 'app-zavastorefront-${environmentName}-${location}'
    location: location
    appServicePlanId: appServicePlan.outputs.id
    managedIdentityId: managedIdentity.outputs.id
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    applicationInsightsConnectionString: monitoring.outputs.applicationInsightsConnectionString
    applicationInsightsInstrumentationKey: monitoring.outputs.applicationInsightsInstrumentationKey
    aiFoundryEndpoint: aiFoundry.outputs.endpoint
    aiFoundryProjectId: aiFoundry.outputs.projectId
    tags: tags
  }
}

// Outputs
output RESOURCE_GROUP_NAME string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output WEB_APP_NAME string = webApp.outputs.name
output WEB_APP_URL string = webApp.outputs.url
output APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
output AI_FOUNDRY_ENDPOINT string = aiFoundry.outputs.endpoint
output AI_FOUNDRY_PROJECT_ID string = aiFoundry.outputs.projectId
output MANAGED_IDENTITY_CLIENT_ID string = managedIdentity.outputs.clientId
