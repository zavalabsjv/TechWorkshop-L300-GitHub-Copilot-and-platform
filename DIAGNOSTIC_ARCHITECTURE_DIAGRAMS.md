# 🏗️ Architecture: Diagnostic Settings Data Flow

**Document Type:** Architecture Reference  
**Last Updated:** December 5, 2025  

---

## Complete Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AI FOUNDRY WORKSPACE                           │
│                                                                         │
│  ┌─────────────────┐              ┌──────────────────┐                │
│  │  AI Foundry Hub │──────────────│ AI Foundry       │                │
│  │                 │  Logs & Data │ Project          │                │
│  └─────────────────┘              └──────────────────┘                │
│         │                                  │                           │
│         │ Generates:                       │ Generates:                │
│         ├─ AmlWorkspaceEvents              ├─ AmlWorkspaceEvents       │
│         ├─ AmlComputeClusterEvent          ├─ AmlComputeClusterEvent   │
│         ├─ AmlComputeInstanceEvent         ├─ AmlComputeInstanceEvent  │
│         ├─ AmlOnlineEndpointConsoleLog     ├─ AmlOnlineEndpointLog     │
│         ├─ AmlDataStoreAccessLog           ├─ AmlDataStoreAccessLog    │
│         ├─ AmlDataPreparationLog           ├─ AmlDataPreparationLog    │
│         ├─ AmlExecutionActivityLog         ├─ AmlExecutionActivityLog  │
│         ├─ AmlNotebookAccessLog            ├─ AmlNotebookAccessLog     │
│         └─ AllMetrics                      └─ AllMetrics               │
│         │                                  │                           │
└─────────┼──────────────────────────────────┼────────────────────────────┘
          │                                  │
          │ Route to Diagnostic Settings     │
          ↓                                  ↓
┌─────────────────────────────────────────────────────────────────────────┐
│              DIAGNOSTIC SETTINGS (Azure Monitor)                       │
│                                                                         │
│  ┌─────────────────────────────────┐   ┌───────────────────────────┐ │
│  │ HubDiagnosticSettings           │   │ ProjectDiagnosticSettings │ │
│  ├─────────────────────────────────┤   ├───────────────────────────┤ │
│  │ name: "diag-aif-zavastorefront" │   │ name: "diag-aif-proj"     │ │
│  │ scope: aiFoundryHub             │   │ scope: aiFoundryProject   │ │
│  │ enabled: true                   │   │ enabled: true             │ │
│  │ retentionPolicy: 0 days         │   │ retentionPolicy: 0 days   │ │
│  └─────────────────────────────────┘   └───────────────────────────┘ │
│         │                                       │                     │
│         └───────────────────┬───────────────────┘                     │
│                             ↓                                         │
│                  Sends all logs and metrics                           │
│                                                                       │
└───────────────────────────────┬───────────────────────────────────────┘
                                │
                                ↓
                ┌──────────────────────────────────┐
                │  LOG ANALYTICS WORKSPACE         │
                │  law-zavastorefront-dev-xxx      │
                ├──────────────────────────────────┤
                │ Ingests: Logs & Metrics          │
                │ Retention: 30 days (default)     │
                │ Searchable: KQL queries          │
                │ Alertable: Azure Monitor alerts  │
                └──────────────────────────────────┘
                          │
                ┌─────────┼─────────────┐
                ↓         ↓             ↓
            ┌────────┐ ┌──────────┐ ┌────────────┐
            │ Queries│ │ Dashbrd  │ │ Alerts &   │
            │ (KQL)  │ │ (Visual) │ │ Actions    │
            └────────┘ └──────────┘ └────────────┘
```

---

## Module Dependency Graph

```
┌──────────────────────┐
│   Resource Group     │
│    (rg)              │
└──────────┬───────────┘
           │
    ┌──────┴──────┬─────────────┬──────────────┬─────────────┐
    │             │             │              │             │
    ↓             ↓             ↓              ↓             ↓
┌────────┐  ┌──────────┐  ┌────────────┐  ┌──────────┐  ┌─────────┐
│Managed │  │Monitoring│  │Container   │  │App Svc   │  │App Svc  │
│Identity│  │          │  │Registry    │  │Plan      │  │         │
└────────┘  └──────────┘  └────────────┘  └──────────┘  └─────────┘
    │           │              │              │            │
    │outputs:   │outputs:      │outputs:      │outputs:    │outputs:
    │.principalId│.logAnalyticsId│.loginServer│.id         │.id
    │.clientId  │.appInsightsId │              │            │
    │.id        │              │              │            │
    │           │              │              │            │
    │   ┌───────┴──────┐       │              │            │
    │   ↓              ↓       │              │            │
    │  AI FOUNDRY ◄────┘       │              │            │
    │  Module                  │              │            │
    │  ├─ hub workspace        │              │            │
    │  ├─ project workspace    │              │            │
    │  ├─ AI Services          │              │            │
    │  ├─ Storage Account      │              │            │
    │  ├─ Key Vault            │              │            │
    │  ├─ RBAC Role Assignment │              │            │
    │  └─ Diagnostic Settings ◄───────────────┘            │
    │     ├─ Hub DS (← Monitoring)                         │
    │     └─ Project DS (← Monitoring)                     │
    │                                                      │
    └──────────────┬────────────────────────────────────────┘
                   │outputs: .id, .endpoint
                   ↓
             ┌──────────┐
             │ Web App  │
             │ Module   │
             └──────────┘
```

**Dependency Order (Automatic):**
1. Resource Group
2. Managed Identity (independent)
3. Monitoring (independent)
4. Container Registry (independent)
5. **AI Foundry** ← Depends on Monitoring (needs logAnalyticsId)
6. App Service Plan (independent)
7. Web App ← Depends on all previous

---

## Log Ingestion Pipeline

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GENERATION PHASE                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. AI Foundry Operations          2. Computed Metrics             │
│  ├─ Workspace events                  ├─ CPU/Memory usage          │
│  ├─ Cluster scaling                   ├─ Storage utilization       │
│  ├─ Job execution                     ├─ Network I/O               │
│  ├─ Data access                       ├─ Request/response times    │
│  └─ Endpoint requests                 └─ Error rates               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │  Azure Monitor      │
                    │  (Diagnostic Svc)   │
                    ├─────────────────────┤
                    │ Collects logs and   │
                    │ metrics from        │
                    │ resource API        │
                    └─────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    ROUTING PHASE                                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Diagnostic Settings Route:                                        │
│  ├─ Hub Diagnostics ─┐                                            │
│  │  name: "diag-..."  │                                            │
│  │  scope: hubId     │─ workspaceId reference                     │
│  └────────────────────┘                                            │
│                      │                                             │
│  └─ Project Diags ──┘                                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────────────────┐
                    │ Log Analytics API   │
                    │ (Ingestion)         │
                    └─────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                   STORAGE PHASE                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Log Analytics Workspace Tables:                                   │
│  ├─ AzureDiagnostics (main table)                                  │
│  │   ├─ TimeGenerated                                              │
│  │   ├─ ResourceProvider: MachineLearningServices                  │
│  │   ├─ ResourceType: workspaces                                   │
│  │   ├─ Category: [8 categories]                                   │
│  │   ├─ OperationName                                              │
│  │   ├─ properties_s (JSON)                                        │
│  │   └─ ... [many more columns]                                    │
│  │                                                                 │
│  └─ Stored with 30-day retention (configurable)                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                   CONSUMPTION PHASE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. KQL Queries (Logs section)                                     │
│     └─ Real-time analysis                                          │
│                                                                     │
│  2. Azure Monitor Alerts                                           │
│     └─ Automated notifications                                     │
│                                                                     │
│  3. Dashboards                                                     │
│     └─ Visual monitoring                                           │
│                                                                     │
│  4. Workbooks                                                      │
│     └─ Interactive reports                                         │
│                                                                     │
│  5. Data Export                                                    │
│     └─ Archive to storage                                          │
│                                                                     │
│  6. Automation Rules                                               │
│     └─ Trigger actions                                             │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Bicep Template Structure

```
main.bicep (Orchestration)
├── params: environmentName, location, resourceToken, tags
│
├── resource: Resource Group
│   └── name: rg-zavastorefront-{env}-{location}
│
├── module: managedIdentity
│   ├── INPUT: name, location, tags
│   └── OUTPUT: id, principalId, clientId
│       │
│       ├─→ AI Foundry (managedIdentityPrincipalId)
│       ├─→ Container Registry (managedIdentityPrincipalId)
│       └─→ Web App (managedIdentityId, managedIdentityClientId)
│
├── module: monitoring
│   ├── INPUT: location, environmentName, tags
│   └── OUTPUT: logAnalyticsWorkspaceId ◄── NEW
│       │
│       └─→ AI Foundry (logAnalyticsWorkspaceId) ◄── NEW DEPENDENCY
│
├── module: containerRegistry
│   ├── INPUT: name, location, managedIdentityPrincipalId, tags
│   └── OUTPUT: id, loginServer
│       │
│       └─→ Web App (containerRegistryLoginServer)
│
├── module: aiFoundry ◄── UPDATED
│   ├── INPUT: 
│   │   ├─ name, location, tags
│   │   ├─ managedIdentityPrincipalId
│   │   └─ logAnalyticsWorkspaceId ◄── NEW PARAM
│   │
│   └── OUTPUT: id, endpoint, projectId
│
├── module: appServicePlan
│   ├── INPUT: name, location, tags
│   └── OUTPUT: id
│
└── module: webApp
    ├── INPUT: [many params]
    └── OUTPUT: name, url

ai-foundry.bicep (Diagnostic Settings) ◄── UPDATED
├── params:
│   ├─ name, location, tags
│   ├─ managedIdentityPrincipalId
│   └─ logAnalyticsWorkspaceId ◄── NEW PARAM
│
├── resources:
│   ├─ storageAccount
│   ├─ keyVault
│   ├─ aiServices
│   ├─ aiFoundryHub
│   ├─ aiFoundryProject
│   ├─ aiServicesConnection
│   ├─ cognitiveServicesRoleAssignment
│   ├─ aiFoundryHubDiagnosticSettings ◄── NEW RESOURCE
│   │   └─ Sends Hub logs → Log Analytics
│   │
│   └─ aiFoundryProjectDiagnosticSettings ◄── NEW RESOURCE
│       └─ Sends Project logs → Log Analytics
│
└── outputs: id, name, endpoint, projectId
```

---

## Configuration Inheritance

```
Bicep Parameter Flow:

main.bicep
│
├─ environmentName="dev"
├─ location="centralus"
└─ tags={...}
    │
    ├─→ monitoring module
    │   ├─ creates Log Analytics
    │   └─ outputs logAnalyticsWorkspaceId
    │       │
    │       └─→ ai-foundry.bicep
    │           ├─ receives logAnalyticsWorkspaceId
    │           ├─ passes to diagnostic settings resources
    │           └─ creates:
    │               ├─ aiFoundryHubDiagnosticSettings
    │               │  └─ workspaceId = logAnalyticsWorkspaceId
    │               │
    │               └─ aiFoundryProjectDiagnosticSettings
    │                  └─ workspaceId = logAnalyticsWorkspaceId
    │
    └─ All modules
        └─ uses: tags={...}
           └─ Applied to all resources
```

---

## Diagnostic Settings Configuration Details

```
Resource Structure:

AI Foundry Hub
    │
    └─→ Diagnostic Settings Resource
        ├─ name: "diag-aif-zavastorefront-dev-centralus"
        ├─ type: Microsoft.Insights/diagnosticSettings@2021-05-01-preview
        ├─ scope: /subscriptions/.../workspaces/aif-zavastorefront-dev-...
        │
        └─ properties:
            │
            ├─ workspaceId: (reference to Log Analytics)
            │
            ├─ logs:
            │   ├─ AmlWorkspaceEvents {enabled: true, retention: 0}
            │   ├─ AmlComputeClusterEvent {enabled: true, retention: 0}
            │   ├─ AmlComputeInstanceEvent {enabled: true, retention: 0}
            │   ├─ AmlOnlineEndpointConsoleLog {enabled: true, retention: 0}
            │   ├─ AmlDataStoreAccessLog {enabled: true, retention: 0}
            │   ├─ AmlDataPreparationLog {enabled: true, retention: 0}
            │   ├─ AmlExecutionActivityLog {enabled: true, retention: 0}
            │   └─ AmlNotebookAccessLog {enabled: true, retention: 0}
            │
            └─ metrics:
                └─ AllMetrics {enabled: true, retention: 0}
```

---

## Log Analytics Schema After Deployment

```
Log Analytics Workspace
│
└─ AzureDiagnostics Table
    │
    ├─ Columns (auto-created):
    │   ├─ TimeGenerated (datetime)
    │   ├─ ResourceProvider (string) = "MachineLearningServices"
    │   ├─ ResourceType (string) = "workspaces"
    │   ├─ ResourceGroup (string)
    │   ├─ SubscriptionId (string)
    │   ├─ ResourceId (string)
    │   ├─ Category (string) = One of 8 categories
    │   ├─ OperationName (string)
    │   ├─ ResultType (string) = "Success" or "Failure"
    │   ├─ ResultDescription (string)
    │   ├─ CallerIpAddress (string)
    │   ├─ CorrelationId (string)
    │   ├─ properties_s (string) = JSON with event details
    │   ├─ MetricName (string) = For metrics
    │   ├─ Average (real) = Metric value
    │   ├─ Minimum (real) = Min value
    │   ├─ Maximum (real) = Max value
    │   └─ Total (real) = Sum value
    │
    ├─ Retention: 30 days (default)
    ├─ Searchable: Yes (KQL)
    ├─ Queryable: Yes
    ├─ Exportable: Yes
    └─ Alertable: Yes
```

---

## Complete Component Interaction

```
┌─────────────────────────────────────────────────────────────────────┐
│                      USER / APPLICATION                            │
└───────────────────────┬─────────────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ↓               ↓               ↓
┌─────────────┐ ┌──────────────┐ ┌──────────────┐
│ Workspace   │ │ Compute      │ │ Online       │
│ Operations  │ │ Cluster      │ │ Endpoint     │
└─────────────┘ └──────────────┘ └──────────────┘
        │               │               │
        └───────────────┼───────────────┘
                        ↓
            ┌───────────────────────┐
            │ AI Foundry Resources  │
            │ ├─ Hub                │
            │ ├─ Project            │
            │ └─ AI Services        │
            └───────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ↓               ↓               ↓
    Logs &         Metrics &      Events &
    Activities     Performance     Errors
        │               │               │
        └───────────────┼───────────────┘
                        ↓
            ┌───────────────────────┐
            │ Azure Monitor         │
            │ (Diagnostic Service)  │
            └───────────────────────┘
                        ↓
        ┌───────────────┼───────────────┐
        ↓               ↓               ↓
    Hub            Project         All Services
    DiagSettings   DiagSettings   Connected
        │               │               │
        └───────────────┼───────────────┘
                        ↓
    ┌───────────────────────────────────────┐
    │ Log Analytics Workspace               │
    │ (Centralized Log Repository)          │
    ├───────────────────────────────────────┤
    │ Storage: AzureDiagnostics table       │
    │ Retention: 30 days                    │
    │ Ingestion: Real-time                  │
    └───────────────────────────────────────┘
                        │
        ┌───────────────┼───────────────────┬────────────┐
        ↓               ↓                   ↓            ↓
    KQL Queries    Alerts &          Dashboards      Export &
    (Real-time)    Automation        (Visual)        Archive
```

---

**Architecture Documentation Complete!** 🏗️

All flows, dependencies, and configurations visualized and documented.

