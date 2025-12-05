# 🔍 Diagnostic Settings Deployment - Testing Report

**Date:** December 5, 2025  
**Status:** ✅ **INFRASTRUCTURE PROVISIONED**  
**Deployment Completion:** 2 minutes 12 seconds  

---

## Deployment Summary

### ✅ Successfully Provisioned Resources

| Resource | Status | Details |
|----------|--------|---------|
| Resource Group | ✅ Done | `rg-zavastorefront-dev-centralus` |
| App Service Plan | ✅ Done | `asp-zavastorefront-dev-centralus` |
| Container Registry | ✅ Done | `acrzavastorec2tmaeyigsq7w` |
| Application Insights | ✅ Done | `appi-zavastorefront-dev-centralus` |
| Log Analytics Workspace | ✅ Done | `law-zavastorefront-dev-centralus` |
| Key Vault | ✅ Done | `kv-aif-rlld3pfbtulgk` |
| Storage Account | ✅ Done | `staifrlld3pfbtulgk` |
| Cognitive Services (AI Services) | ✅ Done | `ais-aif-zavastorefront-dev-centralus` |
| App Service | ✅ Done | `app-zavastorefront-dev-centralus` |

### ✅ Post-Deployment Configuration

**Role Assignment:**
- ✅ Cognitive Services User role assigned to managed identity
- ✅ Principal ID: `5ad72c27-b972-4094-9c53-e9ec656d74c6`
- ✅ Managed Identity: `id-zavastorefront-dev-centralus`
- ✅ Client ID: `76d577c1-60bc-4d7b-b524-75d4386cdde0`

**Diagnostic Settings:**
- ✅ AI Services diagnostic settings configured
- ✅ All available logs and metrics enabled
- ✅ Logs directed to Log Analytics workspace
- ✅ No retention limits (real-time monitoring)

---

## Diagnostic Settings Configuration

### AI Services (Cognitive Services) - COMPLETE

**Resource:** `ais-aif-zavastorefront-dev-centralus`

**Enabled Diagnostics:**

1. **Logs**
   - Category Group: `allLogs` (captures all available log categories)
   - Status: ✅ Enabled
   - Retention: No retention limit (real-time)

2. **Metrics**
   - Category: `AllMetrics` (all available metrics)
   - Status: ✅ Enabled
   - Retention: No retention limit (real-time)

**Destination:**
- Log Analytics Workspace: `law-zavastorefront-dev-centralus`
- Logs table: `AzureDiagnostics`
- Data type: Realtime streaming

### Application Insights (Already Configured)

- ✅ Connection String set in App Service
- ✅ Auto-instrumentation enabled
- ✅ Application logs captured

---

## Testing Instructions

### 1. ✅ App Service Status
**URL:** https://app-zavastorefront-dev-centralus.azurewebsites.net/

**Status:** Running ✅

```bash
# Verify app service is running
az webapp show --name app-zavastorefront-dev-centralus \
  --resource-group rg-zavastorefront-dev-centralus \
  --query "state" -o tsv
# Output: Running
```

### 2. 🧪 Test Chat Feature

**Steps:**
1. Open: https://app-zavastorefront-dev-centralus.azurewebsites.net/
2. Navigate to Chat section
3. Send test messages (e.g., "What products do you have?", "Tell me about your services", etc.)
4. Repeat for 3-5 minutes to generate sufficient logs
5. Observe responses from Phi4 endpoint

**Expected Behavior:**
- Chat responds with product information
- Managed identity authenticates with Phi4 endpoint
- Requests are logged to AI Services

### 3. 🔍 Query Log Analytics

**Open Log Analytics:**
```
Azure Portal → Log Analytics Workspaces → law-zavastorefront-dev-centralus → Logs
```

**Run Query:**
```kusto
AzureDiagnostics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| sort by TimeGenerated desc
```

**Expected Results:**
- See log entries from AI Services (Cognitive Services) resource
- Entries include:
  - `ResourceType`: "accounts" (Cognitive Services account)
  - `ResourceProvider`: "MICROSOFT.COGNITIVESERVICES"
  - `OperationName`: Various API operations
  - `TimeGenerated`: Recent timestamps from your chat requests

**Alternative Queries:**

```kusto
// View recent API calls to Cognitive Services
AzureDiagnostics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| project TimeGenerated, OperationName, ResultSignature, ResourceName
| sort by TimeGenerated desc
| limit 50
```

```kusto
// View metrics for Cognitive Services
AzureMetrics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| where ResourceName startswith "ais-aif"
| project TimeGenerated, MetricName, Average, Maximum
| sort by TimeGenerated desc
| limit 20
```

```kusto
// View chat/inference operations specifically
AzureDiagnostics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| where OperationName contains "InvokeModel" or OperationName contains "chat" or OperationName contains "inference"
| project TimeGenerated, OperationName, StatusCode, DurationMs, ResourceName
| sort by TimeGenerated desc
```

---

## Architecture: Diagnostic Data Flow

```
User sends chat message
         ↓
App Service (WebApp)
    with Managed Identity
         ↓
DefaultAzureCredential
    (uses AZURE_CLIENT_ID)
         ↓
Azure Entra ID
    (generates OAuth token)
         ↓
Phi4 Endpoint
    (Azure AI Services / Cognitive Services)
         ↓
[DIAGNOSTIC TRIGGER]
         ↓
Azure AI Services makes request
         ↓
Diagnostic Settings → Send logs to Log Analytics
         ↓
Log Analytics Workspace
    (law-zavastorefront-dev-centralus)
         ↓
AzureDiagnostics table
    (contains all AI Services events)
         ↓
Available for querying in Azure Portal
```

---

## Configuration Details

### Bicep Resources Created

1. **AI Services Resource** (`ais-aif-zavastorefront-dev-centralus`)
   - Kind: AIServices
   - SKU: S0
   - Endpoint: https://ais-aif-zavastorefront-dev-centralus.cognitiveservices.azure.com/

2. **Diagnostic Settings** (infra/modules/ai-foundry.bicep)
   ```bicep
   resource aiServicesDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
     name: 'diag-${aiServices.name}'
     scope: aiServices
     properties: {
       workspaceId: logAnalyticsWorkspaceId
       logs: [{
         categoryGroup: 'allLogs'
         enabled: true
       }]
       metrics: [{
         category: 'AllMetrics'
         enabled: true
       }]
     }
   }
   ```

3. **Log Analytics Workspace** (infra/modules/monitoring.bicep)
   - Already provisioned
   - SKU: PerGB2018
   - Retention: Default (30 days)

### Environment Configuration

**File:** `.azure/dev/.env`

```
MANAGED_IDENTITY_CLIENT_ID=76d577c1-60bc-4d7b-b524-75d4386cdde0
RESOURCE_GROUP_NAME=rg-zavastorefront-dev-centralus
AZURE_CONTAINER_REGISTRY_NAME=acrzavastorec2tmaeyigsq7w
WEB_APP_NAME=app-zavastorefront-dev-centralus
WEB_APP_URL=https://app-zavastorefront-dev-centralus.azurewebsites.net
```

**App Service Settings:**
- `AZURE_CLIENT_ID`: 76d577c1-60bc-4d7b-b524-75d4386cdde0
- `AI_FOUNDRY_ENDPOINT`: https://ais-aif-zavastorefront-dev-centralus.cognitiveservices.azure.com/
- `APPLICATIONINSIGHTS_CONNECTION_STRING`: ✅ Configured

---

## Fixes Applied

### 1. Diagnostic Settings Categories
**Issue:** Invalid AML diagnostic categories (not supported for AI Services)
**Fix:** Changed to `categoryGroup: 'allLogs'` which captures all available log types

### 2. AI Services Connection Auth Type
**Issue:** ManagedIdentity auth type not supported for connections
**Fix:** Changed to `authType: 'AAD'` for authentication

### 3. Role Assignment Deployment
**Issue:** Role definition lookup failed during initial deployment
**Fix:** Created post-deployment setup script (`post-deployment-setup.ps1`) to assign role after infrastructure provisioning

### 4. Docker Build Context
**Issue:** Path mismatch in Docker build context
**Fix:** Updated Dockerfile paths and azure.yaml context configuration

---

## Verification Checklist

- [x] Infrastructure provisioned successfully
- [x] All resources created in correct resource group
- [x] Diagnostic settings configured for AI Services
- [x] Log Analytics workspace created
- [x] Managed identity attached to App Service
- [x] Cognitive Services User role assigned
- [x] App Service running and accessible
- [ ] Chat feature tested with multiple messages
- [ ] Logs appearing in Log Analytics
- [ ] Query executed successfully

---

## Next Steps

### Immediate (Now)
1. ✅ Test chat feature by sending 5-10 messages to Phi4
2. ⏳ Wait 2-3 minutes for logs to propagate to Log Analytics
3. ✅ Run KQL query to verify logs

### Post-Verification
1. Review log volume and frequency
2. Check for any error logs
3. Monitor performance metrics
4. Create alerts based on diagnostic data

### Optional Enhancements
1. Create Log Analytics alerts for errors
2. Create Power BI dashboard from diagnostic data
3. Configure log retention based on compliance requirements
4. Add more detailed analytics queries

---

## KQL Query Reference

### Query 1: Basic Diagnostic Logs
```kusto
AzureDiagnostics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| sort by TimeGenerated desc
| limit 100
```

**Expected columns:**
- TimeGenerated
- ResourceType
- ResourceName
- OperationName
- StatusCode
- ResourceProvider

### Query 2: Error Analysis
```kusto
AzureDiagnostics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| where StatusCode >= 400
| project TimeGenerated, OperationName, StatusCode, ResourceName, ResultDescription
| sort by TimeGenerated desc
```

### Query 3: Performance Metrics
```kusto
AzureMetrics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| where MetricName in ("ApiCallsPerSecond", "AvailabilityPercentage", "RequestCount")
| project TimeGenerated, MetricName, Average, Maximum, ResourceName
| sort by TimeGenerated desc
```

### Query 4: Daily Summary
```kusto
AzureDiagnostics
| where ResourceProvider =~ "MICROSOFT.COGNITIVESERVICES"
| summarize Count = count(), 
            Errors = countif(StatusCode >= 400),
            AvgTime = avg(DurationMs)
            by bin(TimeGenerated, 1h), OperationName
| sort by TimeGenerated desc
```

---

## Resources

**Log Analytics Workspace:**
- Name: `law-zavastorefront-dev-centralus`
- Location: Central US
- Resource Group: `rg-zavastorefront-dev-centralus`

**Azure Portal Links:**
- Log Analytics: https://portal.azure.com/#@/resource/subscriptions/463a82d4-1896-4332-aeeb-618ee5a5aa93/resourceGroups/rg-zavastorefront-dev-centralus/providers/Microsoft.OperationalInsights/workspaces/law-zavastorefront-dev-centralus/logs
- Cognitive Services: https://portal.azure.com/#@/resource/subscriptions/463a82d4-1896-4332-aeeb-618ee5a5aa93/resourceGroups/rg-zavastorefront-dev-centralus/providers/Microsoft.CognitiveServices/accounts/ais-aif-zavastorefront-dev-centralus/overview

---

**Status:** ✅ **READY FOR TESTING**

All diagnostic settings are configured and deployed. The infrastructure is ready for testing. Proceed with using the chat feature and then verifying logs in Log Analytics.

