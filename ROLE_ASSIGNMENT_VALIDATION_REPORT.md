# Role Assignment Validation Report

## Current State Analysis

### Role Assignment Found ❌
**Status:** A role assignment EXISTS, but it's assigned to the WRONG principal

| Property | Value |
|----------|-------|
| **Assigned To** | `08704d91-5fab-499a-8990-d5537d3e738f` |
| **Principal Name** | `aif-zavastorefront-dev-centralus` |
| **Principal Type** | ManagedIdentity (AI Foundry Hub's system-assigned identity) |
| **Role** | Azure AI Administrator |
| **Scope** | AI Services resource |
| **Created** | 2025-12-04T22:16:01.931875+00:00 |

### Expected Role Assignment ✅
**Should Be Assigned To:** App Service's user-assigned managed identity

| Property | Expected Value |
|----------|-----------------|
| **Should Assign To** | `5ad72c27-b972-4094-9c53-e9ec656d74c6` |
| **Identity Name** | `id-zavastorefront-dev-centralus` |
| **Identity Type** | User-Assigned |
| **Required Role** | Cognitive Services User (or Cognitive Services OpenAI User) |
| **Role ID** | `a97b65f3-24c9-4844-a930-0ef25a3225ec` |

---

## Problem

The current Bicep template (before today's updates) was likely creating a role assignment with an INCORRECT principal ID reference. The role assignment exists, but it's attached to:
- ❌ AI Foundry Hub's system-assigned identity (not what we need)
- ✅ Should be: App Service's user-assigned identity

### Why This Matters

**Current Flow (BROKEN):**
```
App Service (with user-assigned identity)
  ├─ Has: id-zavastorefront-dev-centralus (5ad72c27-b972...)
  ├─ Calls: AI Services endpoint
  ├─ Requests OAuth token using its identity
  ├─ Presents token to AI Services
  └─ Azure checks: Does 5ad72c27... have Cognitive Services role?
     └─ ❌ NO ROLE FOUND → Access Denied

Meanwhile:
AI Foundry Hub (system-assigned identity)
  ├─ Has: aif-zavastorefront-dev-centralus (08704d91-5fab...)
  └─ Has: Azure AI Administrator role on AI Services ✓
     (But this identity doesn't call the API - App Service does!)
```

**Correct Flow (NEEDED):**
```
App Service (with user-assigned identity)
  ├─ Has: id-zavastorefront-dev-centralus (5ad72c27-b972...)
  ├─ Calls: AI Services endpoint
  ├─ Requests OAuth token using its identity
  ├─ Presents token to AI Services
  └─ Azure checks: Does 5ad72c27... have Cognitive Services role?
     └─ ✅ YES - Cognitive Services User role found → Access Granted
```

---

## Fix Required

### Option 1: Remove Old Role Assignment (Manual)
```powershell
$roleAssignmentId = "d98b10b9-eb03-4b43-8b5f-2073b1b0d19f"
az role assignment delete --ids $roleAssignmentId
```

### Option 2: Fix in Bicep (Permanent)
The updated Bicep templates (from today's changes) should:
1. ✅ Accept `managedIdentityPrincipalId` parameter (the App Service's identity)
2. ✅ Create role assignment using the CORRECT principal ID
3. ✅ Include the role assignment in the ai-foundry.bicep module

**Updated ai-foundry.bicep now includes:**
```bicep
resource cognitiveServicesRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiServices.id, managedIdentityPrincipalId, 'a97b65f3-24c9-4844-a930-0ef25a3225ec')
  scope: aiServices
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'a97b65f3-24c9-4844-a930-0ef25a3225ec')
    principalId: managedIdentityPrincipalId  // ← This is App Service's identity!
    principalType: 'ServicePrincipal'
  }
}
```

---

## Recommended Actions

### Step 1: Deploy Updated Bicep
```powershell
az deployment group create \
  --resource-group rg-zavastorefront-dev-centralus \
  --template-file infra/main.bicep \
  --parameters environmentName=dev
```

This will:
- Try to create a NEW role assignment for the App Service's identity
- It may fail if the old one exists (due to GUID conflict)
- If it fails, we'll need to delete the old one first

### Step 2: If Deployment Fails - Clean Old Assignment
```powershell
# Delete the old (incorrect) role assignment
az role assignment delete \
  --role "Azure AI Administrator" \
  --assignee 08704d91-5fab-499a-8990-d5537d3e738f \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-zavastorefront-dev-centralus/providers/Microsoft.CognitiveServices/accounts/ais-aif-zavastorefront-dev-centralus"

# Then redeploy the Bicep
az deployment group create \
  --resource-group rg-zavastorefront-dev-centralus \
  --template-file infra/main.bicep \
  --parameters environmentName=dev
```

### Step 3: Verify the Fix
```powershell
# Check that the App Service's identity now has the Cognitive Services User role
$managedIdentityPrincipalId = "5ad72c27-b972-4094-9c53-e9ec656d74c6"
az role assignment list \
  --assignee $managedIdentityPrincipalId \
  --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/rg-zavastorefront-dev-centralus/providers/Microsoft.CognitiveServices/accounts/ais-aif-zavastorefront-dev-centralus" \
  -o table
```

---

## Summary

| Aspect | Current | Required | Status |
|--------|---------|----------|--------|
| **Role Assignment Exists** | Yes ✓ | Yes ✓ | ✓ |
| **Correct Principal** | No ✗ | App Service identity | ✗ WRONG |
| **Correct Role** | Azure AI Administrator | Cognitive Services User | ✗ WRONG |
| **Scope** | AI Services | AI Services | ✓ |

**Overall:** ❌ The role assignment exists but is assigned to the WRONG identity with the WRONG role.

---

## Root Cause

The previous Bicep template likely had an issue with how it referenced or created the role assignment. Today's updates fix this by:
1. Properly accepting the managed identity principal ID as a parameter
2. Using that principal ID (the App Service's identity) in the role assignment
3. Assigning the correct role: "Cognitive Services User" instead of "Azure AI Administrator"

