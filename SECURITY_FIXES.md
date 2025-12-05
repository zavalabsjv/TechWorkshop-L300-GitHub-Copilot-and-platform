# Security Fixes: Migrate from API Keys to Managed Identity

## Summary of Required Changes

### 1. Bicep Template Updates

#### A. Update `infra/modules/ai-foundry.bicep`

**Change Line 111 from:**
```bicep
authType: 'ApiKey'
```
**To:**
```bicep
authType: 'ManagedIdentity'
```

**Remove Lines 113-115:**
```bicep
credentials: {
  key: aiServices.listKeys().key1
}
```

#### B. Add RBAC Role Assignment in `infra/modules/ai-foundry.bicep`

Add this new resource after the `aiServices` resource (after line 67):

```bicep
// Role assignment for managed identity to access AI Services
resource aiServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, managedIdentityPrincipalId, 'CognitiveServicesUser')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c7-4388-baec-2e87135dc908') // Cognitive Services User
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
```

Add parameter at top of file:
```bicep
@description('Principal ID of the managed identity')
param managedIdentityPrincipalId string
```

#### C. Update `infra/main.bicep`

Update AI Foundry module call (around line 68) to include managed identity:

```bicep
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    name: 'aif-zavastorefront-${environmentName}-${location}'
    location: location
    managedIdentityPrincipalId: managedIdentity.outputs.principalId  // ADD THIS LINE
    tags: tags
  }
}
```

#### D. Update `infra/modules/web-app.bicep`

Remove these app settings (lines 90-94):
```bicep
// REMOVE THESE:
{
  name: 'AI_FOUNDRY_API_KEY'
  value: aiFoundryApiKey  // This should not exist
}
{
  name: 'AI_MODEL_NAME'
  value: 'Phi4'
}
```

Add new app setting:
```bicep
{
  name: 'AZURE_CLIENT_ID'
  value: split(managedIdentityId, '/')[8]  // Client ID for DefaultAzureCredential
}
```

### 2. Source Code Updates

#### A. Add NuGet Packages to `src/ZavaStorefront.csproj`

Add these packages:
```xml
<PackageReference Include="Azure.Identity" Version="1.13.0" />
<PackageReference Include="Azure.AI.Inference" Version="1.0.0-beta.2" />
```

#### B. Replace `src/Services/ChatService.cs` completely

```csharp
using System.Text;
using System.Text.Json;
using Azure.AI.Inference;
using Azure.Core;
using Azure.Identity;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<ChatService> _logger;
        private readonly ChatCompletionsClient? _chatClient;

        public ChatService(IConfiguration configuration, ILogger<ChatService> logger)
        {
            _configuration = configuration;
            _logger = logger;

            try
            {
                var endpoint = _configuration["AI_FOUNDRY_ENDPOINT"];
                
                if (string.IsNullOrEmpty(endpoint))
                {
                    _logger.LogError("Missing AI_FOUNDRY_ENDPOINT configuration");
                    return;
                }

                // Use Managed Identity authentication
                var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                {
                    ManagedIdentityClientId = _configuration["AZURE_CLIENT_ID"]
                });

                _chatClient = new ChatCompletionsClient(new Uri(endpoint), credential);
                _logger.LogInformation("ChatService initialized with managed identity authentication");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize ChatService with managed identity");
            }
        }

        public async Task<string> SendMessageToPhiAsync(string userMessage, string? systemPrompt = null)
        {
            if (_chatClient == null)
            {
                _logger.LogError("ChatService not properly initialized");
                return "Configuration error: Chat service not available.";
            }

            try
            {
                var messages = new List<ChatRequestMessage>();
                
                if (!string.IsNullOrEmpty(systemPrompt))
                {
                    messages.Add(new ChatRequestSystemMessage(systemPrompt));
                }
                messages.Add(new ChatRequestUserMessage(userMessage));

                var requestOptions = new ChatCompletionsOptions
                {
                    Messages = messages,
                    MaxTokens = 500,
                    Temperature = 0.7f
                };

                _logger.LogInformation("Sending message to Phi4 endpoint using managed identity");

                var response = await _chatClient.CompleteAsync(requestOptions);
                var firstChoice = response.Value.Choices[0].Message.Content;

                _logger.LogInformation("Received response from Phi4");
                return firstChoice ?? "No response from Phi4";
            }
            catch (Azure.RequestFailedException ex) when (ex.Status == 401 || ex.Status == 403)
            {
                _logger.LogError(ex, "Authentication failed. Managed identity may not have required permissions.");
                return "Authentication error: Please ensure managed identity has Cognitive Services User role.";
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error calling Phi4 endpoint");
                return $"Error: {ex.Message}";
            }
        }
    }
}
```

### 3. Azure Resource Updates (Manual Steps After Bicep Deploy)

#### Remove API Key from App Service:
```bash
az webapp config appsettings delete \
  --name app-zavastorefront-dev-centralus \
  --resource-group rg-zavastorefront-dev-centralus \
  --setting-names AI_FOUNDRY_API_KEY AI_MODEL_NAME
```

#### Verify Role Assignment:
```bash
# Get AI Services resource ID
AI_SERVICES_ID=$(az cognitiveservices account show \
  --name ais-aif-zavastorefront-dev-centralus \
  --resource-group rg-zavastorefront-dev-centralus \
  --query id -o tsv)

# Get Managed Identity Principal ID
PRINCIPAL_ID=$(az identity show \
  --name id-zavastorefront-dev-centralus \
  --resource-group rg-zavastorefront-dev-centralus \
  --query principalId -o tsv)

# Assign Cognitive Services User role
az role assignment create \
  --role "Cognitive Services User" \
  --assignee-object-id $PRINCIPAL_ID \
  --assignee-principal-type ServicePrincipal \
  --scope $AI_SERVICES_ID
```

### 4. Configuration File Updates

#### Update `src/appsettings.json`:
Remove these lines:
```json
"AI_FOUNDRY_API_KEY": "",
"AI_MODEL_NAME": "Phi4"
```

#### Update `src/appsettings.Development.json`:
Remove entire file or remove sensitive credentials

### Deployment Order

1. Update Bicep templates
2. Redeploy infrastructure: `azd provision`
3. Assign RBAC roles (if not in Bicep)
4. Update source code
5. Remove API keys from configuration
6. Deploy application: `azd deploy`
7. Restart app service
8. Test chat functionality

## Security Benefits

✅ **No API keys in code or configuration**
✅ **No API keys in App Service settings**
✅ **Azure manages authentication tokens automatically**
✅ **Tokens auto-rotate (no manual key rotation)**
✅ **Audit trail via Azure AD sign-in logs**
✅ **Follows Azure security best practices**
