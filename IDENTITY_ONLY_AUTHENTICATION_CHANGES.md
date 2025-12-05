# Identity-Only Authentication Implementation

## Overview
This document outlines the changes made to enforce identity-only (managed identity) authentication for Microsoft Foundry workspace access, completely eliminating API key-based authentication.

## Changes Summary

### 1. **Bicep Template Updates**

#### `infra/main.bicep`
**Change:** Pass managed identity principal ID to the AI Foundry module

**Before:**
```bicep
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    name: 'aif-zavastorefront-${environmentName}-${location}'
    location: location
    tags: tags
  }
}
```

**After:**
```bicep
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    name: 'aif-zavastorefront-${environmentName}-${location}'
    location: location
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    tags: tags
  }
}
```

**Why:** The AI Foundry module now needs the managed identity's principal ID to create RBAC role assignments that allow the identity to authenticate to Azure AI Services.

---

#### `infra/modules/ai-foundry.bicep`
**Changes:** 
1. Added managed identity principal ID parameter
2. Changed AI Services connection from API Key to Managed Identity
3. Removed credential exposure (API key listing)
4. Added RBAC role assignment for Cognitive Services access

**Before:**
```bicep
@description('Tags to apply to the resource')
param tags object = {}
```

**After:**
```bicep
@description('Principal ID of the managed identity for RBAC role assignment')
param managedIdentityPrincipalId string

@description('Tags to apply to the resource')
param tags object = {}
```

**AI Services Connection - Before:**
```bicep
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
```

**AI Services Connection - After:**
```bicep
resource aiServicesConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-04-01' = {
  name: 'aiservices-connection'
  parent: aiFoundryHub
  properties: {
    category: 'AIServices'
    target: aiServices.properties.endpoint
    authType: 'ManagedIdentity'
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiServices.id
    }
  }
}
```

**New RBAC Role Assignment:**
```bicep
resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, managedIdentityPrincipalId, 'a97b65f3-24c9-4844-a930-0ef25a3225ec')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c9-4844-a930-0ef25a3225ec')
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
```

**Why:** 
- **`authType: 'ManagedIdentity'`** tells the AI Foundry workspace to use Entra ID authentication instead of API keys
- **Removed `credentials` block** eliminates exposure of API keys in deployment templates
- **RBAC role assignment** grants the "Cognitive Services User" role (ID: `a97b65f3-24c9-4844-a930-0ef25a3225ec`) to the managed identity on the AI Services resource, enabling it to authenticate and call the Phi4 endpoint

---

#### `infra/modules/web-app.bicep`
**Status:** ✅ No changes needed
- The module already correctly passes only `AI_FOUNDRY_ENDPOINT` and `AI_FOUNDRY_PROJECT_ID`
- API key configuration was never added to this module (good practice maintained)

---

### 2. **Source Code Updates**

#### `src/Services/ChatService.cs`
**Major Changes:**
1. Added `Azure.Identity` namespace import
2. Introduced `DefaultAzureCredential` for managed identity authentication
3. Removed hardcoded API key reading from configuration
4. Changed authentication to use OAuth 2.0 access tokens instead of Bearer token with API key
5. Enhanced error handling for authentication failures

**Before:**
```csharp
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<ChatService> _logger;

        public ChatService(IHttpClientFactory httpClientFactory, IConfiguration configuration, ILogger<ChatService> logger)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<string> SendMessageToPhiAsync(string userMessage, string? systemPrompt = null)
        {
            try
            {
                var endpoint = _configuration["AI_FOUNDRY_ENDPOINT"];
                var apiKey = _configuration["AI_FOUNDRY_API_KEY"];
                var modelName = _configuration["AI_MODEL_NAME"] ?? "Phi4";

                if (string.IsNullOrEmpty(endpoint) || string.IsNullOrEmpty(apiKey))
                {
                    _logger.LogError("Missing Foundry configuration: Endpoint={HasEndpoint}, ApiKey={HasApiKey}", 
                        !string.IsNullOrEmpty(endpoint), 
                        !string.IsNullOrEmpty(apiKey));
                    return "Configuration error: Missing Foundry endpoint or API key.";
                }

                // ... rest of code ...

                // Add authorization header with API key
                client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);

                _logger.LogInformation("Sending message to Phi4 endpoint");
```

**After:**
```csharp
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Identity;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly IHttpClientFactory _httpClientFactory;
        private readonly IConfiguration _configuration;
        private readonly ILogger<ChatService> _logger;
        private readonly DefaultAzureCredential _credential;

        public ChatService(IHttpClientFactory httpClientFactory, IConfiguration configuration, ILogger<ChatService> logger)
        {
            _httpClientFactory = httpClientFactory;
            _configuration = configuration;
            _logger = logger;
            // DefaultAzureCredential will use managed identity when running on Azure
            // For local development, it will fall back to other authentication methods
            _credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
            {
                ExcludeSharedTokenCacheCredential = true
            });
        }

        public async Task<string> SendMessageToPhiAsync(string userMessage, string? systemPrompt = null)
        {
            try
            {
                var endpoint = _configuration["AI_FOUNDRY_ENDPOINT"];
                var modelName = _configuration["AI_MODEL_NAME"] ?? "Phi4";

                if (string.IsNullOrEmpty(endpoint))
                {
                    _logger.LogError("Missing Foundry configuration: Endpoint is required");
                    return "Configuration error: Missing Foundry endpoint.";
                }

                // ... rest of code ...

                var aiServicesResource = "https://cognitiveservices.azure.com";

                // Get access token using managed identity
                var accessToken = await _credential.GetTokenAsync(
                    new Azure.Core.TokenRequestContext(new[] { aiServicesResource + "/.default" }));

                // ... rest of code ...

                // Add authorization header with access token from managed identity
                client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken.Token);

                _logger.LogInformation("Sending message to Phi4 endpoint using managed identity authentication");
```

**New Exception Handler:**
```csharp
            catch (Azure.Identity.AuthenticationFailedException ex)
            {
                _logger.LogError(ex, "Failed to authenticate with Azure Identity (managed identity or fallback credentials)");
                return $"Authentication error: {ex.Message}. Ensure managed identity is properly configured.";
            }
```

**Why:**
- **`DefaultAzureCredential`** automatically uses the managed identity when running in Azure, eliminating the need for API key configuration
- **OAuth token acquisition** is the Azure-recommended pattern for service-to-service authentication
- **Local development support** via credential fallback chain (environment variables, CLI, Visual Studio, etc.)
- **Secure by default** - no credentials stored in configuration files or environment variables on Azure

---

#### `src/ZavaStorefront.csproj`
**Change:** Added Azure.Identity NuGet package

**Before:**
```xml
 <ItemGroup>
     <PackageReference Include="System.Text.Encodings.Web" Version="6.0.0" />
     <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
     <PackageReference Include="Microsoft.Data.SqlClient" Version="5.2.0" />
 </ItemGroup>
```

**After:**
```xml
 <ItemGroup>
     <PackageReference Include="System.Text.Encodings.Web" Version="6.0.0" />
     <PackageReference Include="Newtonsoft.Json" Version="13.0.3" />
     <PackageReference Include="Microsoft.Data.SqlClient" Version="5.2.0" />
     <PackageReference Include="Azure.Identity" Version="1.11.0" />
 </ItemGroup>
```

**Why:** The `Azure.Identity` package provides the `DefaultAzureCredential` class needed for managed identity authentication.

---

## Module Dependencies & Requirements

### Dependency Chain
```
main.bicep
  ├── Depends on: managedIdentity.outputs.principalId
  │   └── Passes to: aiFoundry module
  │
  └── aiFoundry.bicep
      ├── Uses: managedIdentityPrincipalId parameter
      └── Creates: RBAC role assignment that grants Cognitive Services User role
```

### Required Managed Identity Properties
The managed identity must have:
- **Type:** User-Assigned (already configured ✅)
- **Principal ID:** Extracted from managed identity resource and passed through modules
- **RBAC Role:** "Cognitive Services User" on the AI Services resource (created by ai-foundry.bicep)

### App Service Configuration Requirements
The App Service configured with:
- **User-Assigned Identity:** `id-zavastorefront-dev-centralus` (already attached ✅)
- **ACR Access:** Using managed identity credentials (already configured ✅)
- **Configuration Settings:**
  - ✅ `AI_FOUNDRY_ENDPOINT` - Base endpoint to AI Services (required)
  - ✅ `AI_FOUNDRY_PROJECT_ID` - Foundry project ID (required)
  - ❌ `AI_FOUNDRY_API_KEY` - **REMOVED** (no longer needed, can be deleted from Azure)
  - ❌ `AI_MODEL_NAME` - Hardcoded in source code (can be removed from config)

---

## Security Improvements

| Aspect | Before | After | Benefit |
|--------|--------|-------|---------|
| **Authentication** | API Key in config | Managed Identity + OAuth | Keys never stored in configuration |
| **Credential Exposure** | Keys in Bicep (exposed in logs) | Credentials never in IaC | Bicep templates safe to version control |
| **Token Lifetime** | API key has indefinite lifetime | OAuth tokens expire (1 hour) | Automatic token refresh, limited exposure window |
| **Audit Trail** | API key usage not audited | Azure Entra ID audits all calls | Full audit trail via Azure AD logs |
| **Secret Rotation** | Manual key rotation required | Automatic via Azure | No manual key management needed |
| **RBAC Control** | API key grants unlimited access | Fine-grained role assignments | Principle of least privilege |

---

## Deployment Impact

### When Deploying These Changes:

1. **Bicep Deployment:** Run the deployment - the RBAC role assignment is created automatically by `ai-foundry.bicep`
   ```powershell
   az deployment group create --resource-group rg-zavastorefront-dev-centralus --template-file infra/main.bicep --parameters environmentName=dev
   ```

2. **Application Code Deployment:** Deploy the new application code with `Azure.Identity` package
   - The managed identity is automatically available to the application
   - No configuration changes needed in App Service (identity is already attached)

3. **Clean Up (Optional):** Remove API key from App Service settings
   ```powershell
   az webapp config appsettings delete --resource-group rg-zavastorefront-dev-centralus --name app-zavastorefront-dev-centralus --setting-names AI_FOUNDRY_API_KEY AI_MODEL_NAME
   ```

---

## Testing Identity-Only Authentication Locally

For local development testing:

### Option 1: Using Azure CLI Authentication
```powershell
# Login to Azure (DefaultAzureCredential will use this)
az login

# Set subscription
az account set --subscription "your-subscription-id"

# Run the application
cd src
dotnet run
```

### Option 2: Using Service Principal (CI/CD)
```powershell
$env:AZURE_TENANT_ID = "your-tenant-id"
$env:AZURE_CLIENT_ID = "your-client-id"
$env:AZURE_CLIENT_SECRET = "your-client-secret"

dotnet run
```

### Option 3: Using Managed Identity (Azure)
When running on Azure App Service, the managed identity is automatically available - no setup needed!

---

## Files Modified

| File | Changes | Reason |
|------|---------|--------|
| `infra/main.bicep` | Pass managed identity principal ID to ai-foundry module | Enable RBAC role assignment in nested module |
| `infra/modules/ai-foundry.bicep` | Add parameter, change authType, add role assignment, remove credentials | Enforce identity-only authentication |
| `src/Services/ChatService.cs` | Add DefaultAzureCredential, remove API key reading, OAuth token auth | Use managed identity for secure authentication |
| `src/ZavaStorefront.csproj` | Add Azure.Identity package | Required for DefaultAzureCredential |

---

## Verification Checklist

- ✅ Bicep templates pass validation (no API keys in output)
- ✅ Source code compiles successfully
- ✅ Managed identity principal ID flows through module chain
- ✅ RBAC role assignment resource created in ai-foundry.bicep
- ✅ ChatService uses DefaultAzureCredential instead of API key
- ✅ Configuration no longer requires AI_FOUNDRY_API_KEY
- ✅ Error handling includes AuthenticationFailedException

---

## Next Steps

1. **Commit and push changes** to the repository
2. **Deploy the updated Bicep templates** to create RBAC role assignments
3. **Deploy the updated application code** with managed identity authentication
4. **Test chat functionality** to verify managed identity works end-to-end
5. **Monitor Azure AD logs** to confirm identity-based authentication is being used
6. **Remove any remaining API keys** from Azure Key Vault or App Service settings

