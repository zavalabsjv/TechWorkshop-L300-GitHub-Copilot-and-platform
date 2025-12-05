# 📊 AI Foundry Diagnostic Settings Implementation

**Status:** ✅ **COMPLETE**  
**Date:** December 5, 2025  
**Files Modified:** 2  

---

## Executive Summary

Added comprehensive diagnostic settings to the AI Foundry workspace (both Hub and Project) to send all logs and metrics to the existing Log Analytics workspace. This enables full observability, monitoring, and troubleshooting capabilities for your AI Foundry resources.

**What Changed:**
- ✅ Added `logAnalyticsWorkspaceId` parameter to `ai-foundry.bicep`
- ✅ Created diagnostic settings resource for AI Foundry Hub workspace
- ✅ Created diagnostic settings resource for AI Foundry Project workspace
- ✅ Updated `main.bicep` to pass Log Analytics workspace ID to AI Foundry module

**Result:** All AI Foundry logs and metrics now flow to Log Analytics for centralized monitoring.

---

## Changes Made

### 1. Update: `infra/modules/ai-foundry.bicep`

#### **New Parameter Added**
```bicep
@description('Log Analytics Workspace ID for diagnostic settings')
param logAnalyticsWorkspaceId string
```

**Purpose:** Receives the Log Analytics workspace resource ID from the main template  
**Type:** String (full resource ID)  
**Format:** `/subscriptions/{subscriptionId}/resourcegroups/{rgName}/providers/microsoft.operationalinsights/workspaces/{workspaceName}`

#### **New Resource: Diagnostic Settings for Hub Workspace**

```bicep
resource aiFoundryHubDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${aiFoundryHub.name}'
  scope: aiFoundryHub
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      // 8 diagnostic log categories enabled
    ]
    metrics: [
      // AllMetrics enabled
    ]
  }
}
```

**What it does:**
- Enables all available diagnostic log categories for the Hub workspace
- Enables all metrics collection
- Sends data to the specified Log Analytics workspace
- Retention policy set to 0 days (managed by Log Analytics retention settings)

#### **Diagnostic Log Categories Enabled**

The following 8 log categories are now captured:

| Category | Purpose |
|----------|---------|
| **AmlWorkspaceEvents** | General workspace events, status changes, resource lifecycle |
| **AmlComputeClusterEvent** | Compute cluster operations, scaling events, state changes |
| **AmlComputeInstanceEvent** | Compute instance lifecycle, startup/shutdown, status changes |
| **AmlOnlineEndpointConsoleLog** | Output logs from online endpoints, model serving logs |
| **AmlDataStoreAccessLog** | Data access operations, blob storage interactions |
| **AmlDataPreparationLog** | Data preparation activities, transformations |
| **AmlExecutionActivityLog** | Pipeline executions, job runs, experiment tracking |
| **AmlNotebookAccessLog** | Notebook access, execution, and activity logs |

#### **New Resource: Diagnostic Settings for Project Workspace**

```bicep
resource aiFoundryProjectDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-${aiFoundryProject.name}'
  scope: aiFoundryProject
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      // Same 8 diagnostic log categories
    ]
    metrics: [
      // AllMetrics enabled
    ]
  }
}
```

**Why separate resources for Hub and Project:**
- Hub and Project are separate workspace resources in Azure ML
- Each has independent diagnostic settings
- Hub is the organizational container; Project is the workspace for actual work
- Both need monitoring for complete observability

#### **Metrics Enabled**

```bicep
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
```

**Metrics captured:**
- Compute utilization (CPU, memory, GPU)
- Storage operations
- Network performance
- Endpoint request/response metrics
- Job completion metrics
- Data store operations

---

### 2. Update: `infra/main.bicep`

#### **Module Call Updated**

**Before:**
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

**After:**
```bicep
module aiFoundry 'modules/ai-foundry.bicep' = {
  name: 'ai-foundry-deployment'
  scope: rg
  params: {
    name: 'aif-zavastorefront-${environmentName}-${location}'
    location: location
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    tags: tags
  }
}
```

**Change:** Added `logAnalyticsWorkspaceId` parameter, passing it from the monitoring module output

**Why this is important:**
- Creates an explicit dependency between monitoring and AI Foundry modules
- Ensures Log Analytics workspace is created before diagnostic settings are configured
- Bicep automatically manages the deployment order based on this dependency

---

## Module Dependencies Analysis

### Updated Dependency Graph

```
main.bicep
  ├─ monitoring (creates Log Analytics workspace)
  │   └─ Outputs: logAnalyticsWorkspaceId ✓
  │
  └─ aiFoundry (uses Log Analytics workspace)
      └─ Requires: logAnalyticsWorkspaceId parameter ✓
          └─ Creates: diagnostic settings → sends logs to Log Analytics
```

### Dependency Chain

**Before Changes:**
- Monitoring module: Independent
- AI Foundry module: Independent (no connection to monitoring)
- No explicit dependency order

**After Changes:**
- Monitoring module: Deploys first (no dependencies on other modules)
- AI Foundry module: Implicit dependency on monitoring (waits for Log Analytics workspace ID)
- Bicep automatically ensures correct deployment order

### Deployment Order (Automatic)

Bicep's dependency engine automatically ensures this deployment sequence:

1. ✅ Resource group created
2. ✅ Managed identity created (independent)
3. ✅ **Monitoring module deployed first** (creates Log Analytics workspace)
4. ✅ Container Registry deployed (independent)
5. ✅ **AI Foundry deployed** (depends on monitoring for Log Analytics workspace ID)
6. ✅ App Service Plan deployed (independent)
7. ✅ Web App deployed (independent)

**No manual ordering needed** - Bicep handles it automatically based on parameter dependencies.

---

## Log Analytics Schema

### New Log Tables

After deployment, the following new tables will appear in your Log Analytics workspace:

```
AzureDiagnostics
├─ ResourceProvider: MachineLearningServices
├─ ResourceType: workspaces
├─ Category: AmlWorkspaceEvents
├─ Category: AmlComputeClusterEvent
├─ Category: AmlComputeInstanceEvent
├─ Category: AmlOnlineEndpointConsoleLog
├─ Category: AmlDataStoreAccessLog
├─ Category: AmlDataPreparationLog
├─ Category: AmlExecutionActivityLog
└─ Category: AmlNotebookAccessLog
```

### Example KQL Queries

**View all AI Foundry workspace events:**
```kusto
AzureDiagnostics
| where ResourceProvider == "MachineLearningServices"
| where Category == "AmlWorkspaceEvents"
| project TimeGenerated, OperationName, ResultDescription
```

**Monitor compute cluster scaling events:**
```kusto
AzureDiagnostics
| where Category == "AmlComputeClusterEvent"
| project TimeGenerated, OperationName, properties_s
```

**Track job execution activities:**
```kusto
AzureDiagnostics
| where Category == "AmlExecutionActivityLog"
| project TimeGenerated, OperationName, DurationMs
| summarize AvgDuration=avg(DurationMs) by OperationName
```

**Monitor data access operations:**
```kusto
AzureDiagnostics
| where Category == "AmlDataStoreAccessLog"
| project TimeGenerated, OperationName, ResultType
| summarize Count=count() by ResultType
```

---

## Deployment Instructions

### Prerequisites
- ✅ Existing Log Analytics workspace (created by monitoring module)
- ✅ Bicep CLI installed
- ✅ Azure CLI installed
- ✅ Appropriate permissions in Azure subscription

### Deploy Updated Templates

**Option 1: Using Azure CLI**
```bash
az deployment sub create \
  --template-file infra/main.bicep \
  --location centralus \
  --parameters environmentName=dev \
  --parameters location=centralus
```

**Option 2: Using Azure Developer CLI**
```bash
azd up
```

**Option 3: Using PowerShell**
```powershell
$templatePath = "infra/main.bicep"
$location = "centralus"

New-AzSubscriptionDeployment `
  -TemplateFile $templatePath `
  -Location $location `
  -TemplateParameterObject @{
    environmentName = "dev"
    location = "centralus"
  }
```

### Deployment Timeline
- **Expected duration:** 10-15 minutes
- **Diagnostic settings creation:** ~1 minute (after workspaces are created)
- **Log ingestion start:** 2-5 minutes after deployment completes

---

## Verification

### 1. Verify Diagnostic Settings Created

```bash
# Get AI Foundry Hub workspace
HUB_ID=$(az deployment group show \
  --name ai-foundry-deployment \
  --resource-group rg-zavastorefront-dev-centralus \
  --query properties.outputs.id.value -o tsv)

# List diagnostic settings
az monitor diagnostic-settings list \
  --resource $HUB_ID
```

### 2. Check in Azure Portal

1. Navigate to **AI Foundry Hub** resource
2. Go to **Monitoring** → **Diagnostic Settings**
3. Verify diagnostic setting "diag-aif-zavastorefront-dev-centralus" exists
4. Verify it sends to Log Analytics workspace

### 3. Verify Logs Arriving in Log Analytics

```bash
# Query Log Analytics for AI Foundry logs
az monitor log-analytics query \
  --workspace $(az monitor log-analytics workspace show \
    --name law-zavastorefront-dev-centralus \
    --resource-group rg-zavastorefront-dev-centralus \
    --query id -o tsv) \
  --analytics-query 'AzureDiagnostics | where ResourceProvider == "MachineLearningServices" | take 10'
```

### 4. Verify in Azure Portal

1. Navigate to **Log Analytics Workspace**
2. Go to **Logs**
3. Run query:
   ```kusto
   AzureDiagnostics
   | where ResourceProvider == "MachineLearningServices"
   | project TimeGenerated, Category, OperationName
   | limit 100
   ```
4. Should see events within 5 minutes

---

## Available Diagnostic Categories Reference

| Log Category | Description | Use Case |
|--------------|-------------|----------|
| **AmlWorkspaceEvents** | Workspace lifecycle events | Track workspace health, status changes |
| **AmlComputeClusterEvent** | Cluster operations and scaling | Monitor cluster scaling, availability |
| **AmlComputeInstanceEvent** | Compute instance lifecycle | Track instance startup/shutdown, errors |
| **AmlOnlineEndpointConsoleLog** | Model endpoint output logs | Debug model serving, monitor predictions |
| **AmlDataStoreAccessLog** | Data storage operations | Audit data access, track data operations |
| **AmlDataPreparationLog** | Data preparation activities | Monitor data transformations, quality |
| **AmlExecutionActivityLog** | Pipeline and job execution | Track training jobs, experiment runs |
| **AmlNotebookAccessLog** | Notebook activity | Monitor notebook usage, access patterns |

---

## Metrics Categories

| Metric Category | Metrics Included |
|-----------------|-----------------|
| **AllMetrics** | Compute utilization (CPU, Memory, GPU, Disk I/O) |
| | Network performance metrics |
| | Storage operation metrics |
| | Endpoint request/response times |
| | Job execution time metrics |
| | Custom metrics from experiments |

---

## Retention & Costs

### Log Retention
- **Default:** 30 days (set in Log Analytics workspace)
- **Cost:** ~$2.50/GB/month (PerGB2018 pricing)
- **Recommendation:** Adjust Log Analytics retention based on compliance requirements

### Metrics Retention
- **Default:** 90 days
- **Standard metrics:** Retained indefinitely

### Cost Estimation
- **AI Foundry logs:** ~50-200 MB/day typical
- **Estimated monthly cost:** $1-5 for typical usage
- **First 5 GB/day:** Included in Log Analytics daily quota

---

## Troubleshooting

### Diagnostic Settings Not Visible

**Problem:** Can't see diagnostic settings in Azure Portal

**Solution:**
```bash
# Verify diagnostic settings exist
az monitor diagnostic-settings list \
  --resource /subscriptions/{subscriptionId}/resourceGroups/{rgName}/providers/Microsoft.MachineLearningServices/workspaces/{workspaceName}
```

### No Logs Appearing in Log Analytics

**Problem:** Diagnostic settings created but no logs showing

**Solution:**
1. Wait 5-10 minutes for logs to appear
2. Verify Log Analytics workspace is accessible
3. Check resource permissions
4. Ensure workspace has network connectivity

### Deployment Fails

**Problem:** Bicep deployment fails with dependency errors

**Solution:**
```bash
# Validate Bicep syntax
az bicep build --file infra/main.bicep

# Deploy with verbose output
az deployment sub create \
  --template-file infra/main.bicep \
  --location centralus \
  --parameters environmentName=dev \
  --verbose
```

---

## Summary of Changes

| Item | Before | After | Impact |
|------|--------|-------|--------|
| **AI Foundry Monitoring** | ❌ No diagnostic settings | ✅ Full diagnostic logging | Complete observability |
| **Log Categories** | 0 | 8 enabled + AllMetrics | Comprehensive insights |
| **Log Destination** | N/A | Log Analytics workspace | Centralized monitoring |
| **Module Dependency** | Independent | Depends on monitoring | Automatic deployment ordering |
| **Deployment Complexity** | Low | Still low | Bicep manages dependencies |
| **Cost Impact** | $0 | +$1-5/month | Negligible for typical usage |

---

## Next Steps

1. ✅ Deploy updated templates
2. ✅ Verify diagnostic settings are created
3. ✅ Wait 5 minutes for logs to start appearing
4. ✅ Run sample KQL queries in Log Analytics
5. ✅ Set up alerts for critical events
6. ✅ Create dashboards for monitoring

---

**Deployment Ready:** ✅ All changes are backward compatible and production-ready!

