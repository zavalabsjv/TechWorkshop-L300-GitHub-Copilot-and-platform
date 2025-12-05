# 📋 AI Foundry Diagnostic Categories Reference

**Document Type:** Technical Reference  
**Purpose:** Detailed explanation of all diagnostic log categories  
**Last Updated:** December 5, 2025  

---

## Overview

The AI Foundry diagnostic settings now capture **8 diagnostic log categories** plus **all metrics**. This document provides detailed information about what each category captures and how to use the data.

---

## Diagnostic Log Categories

### 1. AmlWorkspaceEvents

**What it captures:**
- Workspace creation, update, deletion
- Workspace status changes
- Resource lifecycle events
- Workspace configuration changes
- Permission changes
- Compute resource attachments/detachments
- Quota changes
- General workspace operational events

**Example events:**
- Workspace created
- Workspace deleted
- Storage account attached
- Key Vault attached
- Compute resource added/removed
- Workspace configuration updated

**Typical log volume:** 10-50 events/day

**Use cases:**
- Track workspace configuration changes
- Audit who modified workspace settings
- Monitor workspace creation/deletion
- Track resource attachments

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlWorkspaceEvents"
| project TimeGenerated, OperationName, CallerIpAddress, Claims
| where OperationName contains "Create" or OperationName contains "Delete"
```

---

### 2. AmlComputeClusterEvent

**What it captures:**
- Cluster creation/deletion
- Cluster scaling events (scale up/down)
- Node allocation/deallocation
- Cluster state transitions
- Cluster configuration changes
- Cluster status monitoring
- Cluster error conditions

**Example events:**
- Compute cluster created
- Cluster scaled from 2 to 5 nodes
- Cluster failed to scale
- Node added/removed
- Cluster idle timeout
- Cluster deleted

**Typical log volume:** 5-100 events/day (depends on cluster activity)

**Use cases:**
- Monitor cluster scaling behavior
- Track cluster availability issues
- Debug scaling failures
- Analyze compute utilization patterns
- Audit cluster cost optimization

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlComputeClusterEvent"
| project TimeGenerated, OperationName, properties_s
| where OperationName contains "Scale"
| summarize Count=count() by OperationName, bin(TimeGenerated, 1h)
```

---

### 3. AmlComputeInstanceEvent

**What it captures:**
- Compute instance creation/deletion
- Instance startup/shutdown
- Instance state transitions
- Instance errors and failures
- Instance configuration changes
- SSH access events
- Instance restart events
- Out-of-memory errors
- Instance status monitoring

**Example events:**
- Compute instance created
- Instance started
- Instance failed to start (out of memory)
- Instance stopped
- SSH connection established
- Instance deleted
- Instance restarted
- Application crashed

**Typical log volume:** 5-50 events/day per instance

**Use cases:**
- Monitor instance health and availability
- Debug startup failures
- Track SSH access for security audits
- Identify memory/resource issues
- Troubleshoot application crashes
- Track instance lifecycle

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlComputeInstanceEvent"
| where OperationName contains "Failed" or OperationName contains "Error"
| project TimeGenerated, OperationName, ResultDescription
| top 50 by TimeGenerated desc
```

---

### 4. AmlOnlineEndpointConsoleLog

**What it captures:**
- Model endpoint initialization logs
- Endpoint request/response logs
- Endpoint error logs
- Application stdout/stderr
- Custom logging from deployed models
- Endpoint startup logs
- Endpoint shutdown logs
- Model scoring activity logs

**Example events:**
- Endpoint deployed
- Model loaded successfully
- Scoring request received
- Prediction generated
- Error during scoring
- Application exception
- Endpoint shutdown
- Custom log messages from model code

**Typical log volume:** 100-10,000+ events/day (depends on traffic)

**Use cases:**
- Debug model serving issues
- Monitor prediction accuracy and latency
- Track endpoint errors
- Monitor application performance
- Debug custom code in models
- Track endpoint activity
- Compliance/audit of predictions

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlOnlineEndpointConsoleLog"
| project TimeGenerated, properties_s
| where properties_s contains "error" or properties_s contains "Error"
| summarize ErrorCount=count() by bin(TimeGenerated, 1h)
```

---

### 5. AmlDataStoreAccessLog

**What it captures:**
- Data store connection events
- Blob storage access (read/write/delete)
- File access operations
- Azure Data Lake access
- Access control checks
- Data transfer operations
- Access failures/denials
- Authentication attempts

**Example events:**
- Connected to blob storage
- File uploaded
- File downloaded
- Blob deleted
- Access denied (permission error)
- Connection failed
- Data transfer completed
- Large file operation (>1GB)

**Typical log volume:** 5-50 events/day for typical usage

**Use cases:**
- Audit data access patterns
- Monitor data security
- Track who accessed what data
- Debug data access failures
- Monitor data transfer performance
- Compliance/regulatory audit trails
- Detect unusual access patterns

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlDataStoreAccessLog"
| project TimeGenerated, OperationName, CallerIpAddress, ResultType
| where ResultType == "Failure"
| summarize FailureCount=count() by OperationName
```

---

### 6. AmlDataPreparationLog

**What it captures:**
- Data transformation operations
- Data validation results
- Data quality checks
- Data schema changes
- Data type conversions
- Missing value handling
- Data cleaning operations
- Feature engineering steps
- Data sampling operations

**Example events:**
- Data import started/completed
- Validation passed/failed
- Records removed (outliers, nulls)
- Schema detected
- Transformation applied
- Feature created
- Data profile generated
- Quality check passed/failed

**Typical log volume:** 10-100 events/day per data preparation job

**Use cases:**
- Track data transformation steps
- Debug data quality issues
- Monitor data preparation performance
- Audit data lineage
- Track schema changes
- Monitor failed validations
- Analyze data preparation efficiency

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlDataPreparationLog"
| where properties_s contains "Validation"
| project TimeGenerated, properties_s
| summarize FailureCount=count(iff(properties_s contains "Failed", 1, 0))
```

---

### 7. AmlExecutionActivityLog

**What it captures:**
- Pipeline execution start/completion
- Training job start/completion
- Job status transitions
- Job errors and failures
- Job metrics and results
- Experiment runs
- Hyperparameter tuning progress
- AutoML runs
- Job resource allocation
- Job cleanup

**Example events:**
- Training job started
- Job completed successfully
- Job failed with error
- Model accuracy: 0.95
- Job timeout
- Resource allocation failed
- Cleanup completed
- Inference job started

**Typical log volume:** 5-50 events/day (depends on experiment activity)

**Use cases:**
- Monitor training job progress
- Track experiment results
- Debug failed jobs
- Analyze job performance metrics
- Monitor resource utilization
- Audit experiment runs
- Track model training history
- Monitor AutoML progress

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlExecutionActivityLog"
| project TimeGenerated, OperationName, DurationMs
| where OperationName == "TrainingJobCompleted"
| summarize AvgDuration=avg(DurationMs), MaxDuration=max(DurationMs) by bin(TimeGenerated, 1d)
```

---

### 8. AmlNotebookAccessLog

**What it captures:**
- Notebook file access
- Notebook cell execution
- Notebook kernel events
- Notebook dependencies loaded
- Notebook output generated
- User access to notebooks
- Notebook save/load operations
- Session start/end
- Variable state changes (optional)

**Example events:**
- Notebook file opened
- Cell executed
- Cell execution failed
- Kernel started
- Package imported
- Output generated
- Notebook saved
- Session ended
- User accessed notebook

**Typical log volume:** 5-100 events/day per active notebook

**Use cases:**
- Track notebook usage patterns
- Audit who accessed which notebooks
- Monitor notebook execution
- Debug notebook errors
- Track code execution history
- Monitor computational resources
- Analyze development patterns
- Compliance tracking

**KQL Example:**
```kusto
AzureDiagnostics
| where Category == "AmlNotebookAccessLog"
| project TimeGenerated, CallerIpAddress, OperationName
| where OperationName contains "Execute"
| summarize ExecutionCount=count() by CallerIpAddress
```

---

## Metrics Categories

### AllMetrics

When enabled, this captures all available metrics for the workspace:

#### Compute Metrics
- **CPU Utilization %**: Average, min, max CPU usage
- **Memory Utilization %**: RAM usage percentage
- **GPU Utilization %**: GPU usage (if applicable)
- **Disk I/O**: Read/write operations
- **Network I/O**: Bytes sent/received

#### Storage Metrics
- **Blob Count**: Number of blobs in storage
- **Container Count**: Number of containers
- **Storage Used (Bytes)**: Total storage consumption
- **Operation Count**: Total operations performed

#### Endpoint Metrics
- **Request Count**: Number of scoring requests
- **Response Time**: Average latency
- **Success Rate**: % of successful predictions
- **Error Rate**: % of failed predictions
- **CPU Utilization**: Endpoint CPU usage
- **Memory Utilization**: Endpoint memory usage

#### Job Metrics
- **Job Duration**: Training job execution time
- **Job Success Rate**: % of successful jobs
- **Job Failure Rate**: % of failed jobs
- **Resource Allocation**: Cores, memory allocated
- **Data Size**: Input/output data volume

#### Custom Metrics
- Metrics logged by training scripts
- Model-specific metrics
- Business metrics
- Application-specific KPIs

---

## Log Volume Estimates

| Category | Typical Volume | Peak Volume | Storage/Month |
|----------|---|---|---|
| AmlWorkspaceEvents | 10-50/day | 100/day | ~5 MB |
| AmlComputeClusterEvent | 5-100/day | 500/day | ~20 MB |
| AmlComputeInstanceEvent | 5-50/day | 200/day | ~15 MB |
| AmlOnlineEndpointConsoleLog | 100-10K/day | 100K/day | 500 MB+ |
| AmlDataStoreAccessLog | 5-50/day | 500/day | ~20 MB |
| AmlDataPreparationLog | 10-100/day | 1K/day | ~50 MB |
| AmlExecutionActivityLog | 5-50/day | 200/day | ~15 MB |
| AmlNotebookAccessLog | 5-100/day | 500/day | ~30 MB |
| **AllMetrics** | ~100/min | ~1K/min | ~200 MB |
| **TOTAL ESTIMATE** | | | ~850 MB - 2 GB |

**Cost for typical usage:** ~$2-5/month with PerGB2018 pricing

---

## Recommended Queries

### Dashboard: Overall Health
```kusto
let timeWindow = 7d;
AzureDiagnostics
| where TimeGenerated > ago(timeWindow)
| where ResourceProvider == "MachineLearningServices"
| summarize TotalEvents=count() by Category
| render barchart
```

### Alert: Job Failures
```kusto
AzureDiagnostics
| where Category == "AmlExecutionActivityLog"
| where OperationName contains "Failed"
| where TimeGenerated > ago(1h)
| project TimeGenerated, OperationName, ErrorDescription=tostring(properties_s)
```

### Analyze: Cluster Scaling
```kusto
AzureDiagnostics
| where Category == "AmlComputeClusterEvent"
| where OperationName contains "Scale"
| project TimeGenerated, ClusterName=tostring(properties_s.ClusterName), NewNodeCount=toint(properties_s.NewNodeCount)
| sort by TimeGenerated desc
```

### Monitor: Endpoint Performance
```kusto
AzureDiagnostics
| where Category == "AmlOnlineEndpointConsoleLog"
| project TimeGenerated, Latency=toint(properties_s.latency_ms), Status=tostring(properties_s.status)
| summarize AvgLatency=avg(Latency), SuccessRate=100*todouble(countif(Status=="200"))/count() by bin(TimeGenerated, 5m)
```

### Audit: Data Access
```kusto
AzureDiagnostics
| where Category == "AmlDataStoreAccessLog"
| where ResultType == "Failure"
| project TimeGenerated, CallerIpAddress, OperationName, ResultDescription
| summarize FailureCount=count() by CallerIpAddress, OperationName
```

---

## Retention & Archival

### Log Analytics Retention
- **Default:** 30 days
- **Maximum:** 730 days (2 years) with extra cost
- **Recommendation:** 30-90 days for cost optimization

### Archive Strategy
For long-term retention:
```bicep
// Consider adding to Bicep:
resource dataExportRule 'Microsoft.OperationalInsights/workspaces/dataExports@2020-08-01' = {
  name: 'export-to-storage'
  parent: logAnalyticsWorkspace
  properties: {
    destination: {
      resourceId: storageAccount.id
    }
    tableNames: [
      'AzureDiagnostics'
    ]
    enable: true
    createdDate: utcNow()
    lastModifiedDate: utcNow()
  }
}
```

---

## Troubleshooting Missing Logs

| Issue | Cause | Solution |
|-------|-------|----------|
| No logs appearing | Diagnostic settings not enabled | Re-deploy Bicep template |
| Wrong workspace | Diagnostic points to wrong LA | Update diagnostic settings |
| Logs stopped | Workspace quota exceeded | Increase Log Analytics quota |
| Latency | Network issue | Check network connectivity |
| Logs too verbose | All categories enabled | Disable unnecessary categories |
| Storage full | Retention too long | Reduce retention period |

---

**Reference Complete:** All diagnostic categories documented and ready for use! 🎯

