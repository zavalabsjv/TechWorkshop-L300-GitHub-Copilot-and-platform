# Module Dependencies & Parameter Flow

## Parameter Flow Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                        main.bicep                                │
│                                                                  │
│  Module: managedIdentity                                        │
│  ├─ Output: principalId                                         │
│  └─ Output: clientId                                            │
│                                                                  │
│  This is then passed to aiFoundry module:                       │
│  ▼                                                               │
│  Module: aiFoundry                                              │
│  ├─ Parameter: managedIdentityPrincipalId ◄────────────────────┤
│  │  (receives: managedIdentity.outputs.principalId)             │
│  │                                                               │
│  │  Uses it to create:                                          │
│  │  └─ Role Assignment resource                                │
│  │     └─ Assigns "Cognitive Services User" role               │
│  │        └─ To: managed identity (principalId)                │
│  │        └─ On: AI Services resource                          │
│  │                                                               │
│  └─ Output: endpoint                                            │
│                                                                  │
│  Module: webApp                                                 │
│  ├─ Parameter: managedIdentityId (resource ID)                 │
│  │  (receives: managedIdentity.outputs.id)                      │
│  │  ├─ Attaches identity to App Service                        │
│  │  └─ Configures App Service with                             │
│  │     - AI_FOUNDRY_ENDPOINT                                   │
│  │     - AI_FOUNDRY_PROJECT_ID                                 │
│  └─ Output: url                                                 │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Detailed Parameter Mapping

### 1. Managed Identity Module → Main Module
```bicep
module managedIdentity 'modules/managed-identity.bicep' = {
  // ...params...
}

// Outputs available:
// - managedIdentity.outputs.id          // Full resource ID
// - managedIdentity.outputs.principalId // GUID for RBAC assignments
// - managedIdentity.outputs.clientId    // GUID for app configuration
```

### 2. Main Module → AI Foundry Module
```bicep
module aiFoundry 'modules/ai-foundry.bicep' = {
  params: {
    // NEW: Pass the principal ID for RBAC role assignment
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    // ...other params...
  }
}
```

### 3. AI Foundry Module - Uses Principal ID
```bicep
param managedIdentityPrincipalId string

// Uses it in role assignment:
resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  properties: {
    principalId: managedIdentityPrincipalId  // ◄── Used here
    // ...other properties...
  }
}
```

### 4. Main Module → Web App Module
```bicep
module webApp 'modules/web-app.bicep' = {
  params: {
    // Pass the identity resource ID (not principal ID)
    managedIdentityId: managedIdentity.outputs.id
    // ...other params...
  }
}
```

### 5. Web App Module - Attaches Identity
```bicep
param managedIdentityId string

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}  // ◄── Used here
    }
  }
  // ...rest of config...
}
```

---

## Module Dependencies Table

| Module | Depends On | What It Receives | How It Uses It |
|--------|-----------|------------------|----------------|
| **managedIdentity** | None | None | Creates user-assigned identity |
| **aiFoundry** | managedIdentity | `principalId` (GUID) | Creates RBAC role assignment granting Cognitive Services User role |
| **webApp** | managedIdentity | `id` (resource ID) | Attaches identity to App Service so it can use the role assignment |
| **appServicePlan** | None | None | Provides compute plan for webApp |
| **containerRegistry** | managedIdentity | `principalId` | Creates ACR pull role assignment (separate auth path) |

---

## Authentication Flow at Runtime

```
┌──────────────────────────────────────┐
│  1. App Service Starts               │
│  ├─ Managed identity: attached ✓     │
│  └─ Identity available to code ✓     │
└────────────────┬─────────────────────┘
                 │
┌────────────────▼─────────────────────┐
│  2. ChatService Initializes           │
│  ├─ DefaultAzureCredential created   │
│  └─ Discovers attached identity      │
└────────────────┬─────────────────────┘
                 │
┌────────────────▼─────────────────────┐
│  3. User Sends Chat Message           │
│  └─ Calls: SendMessageToPhiAsync()   │
└────────────────┬─────────────────────┘
                 │
┌────────────────▼─────────────────────┐
│  4. Request OAuth Token               │
│  ├─ Credential.GetTokenAsync()       │
│  ├─ Resource: cognitiveservices.azure│
│  ├─ Uses: managed identity ✓         │
│  └─ Gets: access token (valid 1hr)   │
└────────────────┬─────────────────────┘
                 │
┌────────────────▼─────────────────────┐
│  5. Call AI Services Endpoint         │
│  ├─ Authorization: Bearer {token}    │
│  ├─ Azure validates token            │
│  ├─ Checks: principalId has role ✓   │
│  ├─ Role grants: Cognitive Services  │
│  │  User access ✓                    │
│  └─ Processes: chat request ✓        │
└────────────────┬─────────────────────┘
                 │
┌────────────────▼─────────────────────┐
│  6. Response Received                 │
│  └─ Full audit trail in Azure AD ✓   │
└──────────────────────────────────────┘
```

---

## Key Points About Module Dependencies

### ✅ What's Correctly Implemented
- Principal ID flows from managedIdentity → aiFoundry module ✓
- Identity resource ID flows from managedIdentity → webApp module ✓
- Role assignment created at deployment time ✓
- All dependencies resolved in correct order ✓
- No circular dependencies ✓

### ✅ No Changes Needed To
- **managed-identity.bicep** - Already correct
- **web-app.bicep** - Already correct (already uses identity ID)
- **container-registry.bicep** - Works with existing principal ID parameter
- **monitoring.bicep** - No identity dependencies
- **app-service-plan.bicep** - No identity dependencies

### ⚠️ Changes Made To
- **main.bicep** - Added principal ID parameter to aiFoundry call ✓
- **ai-foundry.bicep** - Added principal ID parameter and role assignment ✓

---

## Verifying Dependencies After Deployment

```powershell
# 1. Check if role assignment was created
az role assignment list \
  --scope /subscriptions/{subscription}/resourceGroups/rg-zavastorefront-dev-centralus/providers/Microsoft.CognitiveServices/accounts/ais-aif-zavastorefront-dev-centralus \
  --query "[].principalId" \
  -o json

# 2. Verify the principal ID matches managed identity
az identity show \
  --name id-zavastorefront-dev-centralus \
  --resource-group rg-zavastorefront-dev-centralus \
  --query principalId \
  -o tsv

# 3. Verify identity is attached to App Service
az webapp identity show \
  --name app-zavastorefront-dev-centralus \
  --resource-group rg-zavastorefront-dev-centralus \
  --query userAssignedIdentities \
  -o json

# All three commands should show relationships confirming:
# - Identity created ✓
# - Identity attached to App Service ✓
# - Identity has role assignment on AI Services ✓
```

---

## Summary: Module Dependency Status

| Aspect | Status | Details |
|--------|--------|---------|
| Parameter flow | ✅ Correct | principalId passes through main.bicep to aiFoundry.bicep |
| Role assignment | ✅ Correct | RBAC role assignment created using passed principal ID |
| Identity attachment | ✅ Correct | Identity resource ID correctly attached to App Service |
| Circular dependencies | ✅ None | All dependencies flow in correct direction |
| Module adjustments needed | ✅ Minimal | Only main.bicep and ai-foundry.bicep modified |
| Other modules compatible | ✅ Yes | web-app, app-service-plan, monitoring, container-registry all work correctly |

