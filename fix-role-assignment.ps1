#!/usr/bin/env pwsh
# Fix role assignment for App Service managed identity on AI Services

# Configuration
$ResourceGroupName = "rg-zavastorefront-dev-centralus"
$AiServicesName = "ais-aif-zavastorefront-dev-centralus"
$ManagedIdentityName = "id-zavastorefront-dev-centralus"

# Cognitive Services User role ID
$CognitiveServicesUserRoleId = "a97b65f3-24c9-4844-a930-0ef25a3225ec"

Write-Host "🔍 Validating role assignments for identity-only authentication..." -ForegroundColor Cyan

# Step 1: Get the managed identity principal ID
Write-Host "Step 1: Retrieving App Service managed identity..." -ForegroundColor Yellow
try {
    $managedIdentity = az identity show `
        --name $ManagedIdentityName `
        --resource-group $ResourceGroupName `
        --query "{PrincipalId:principalId, ClientId:clientId, Name:name}" `
        -o json | ConvertFrom-Json
    
    $appServicePrincipalId = $managedIdentity.PrincipalId
    Write-Host "✓ Found managed identity: $($managedIdentity.Name)" -ForegroundColor Green
    Write-Host "  Principal ID: $appServicePrincipalId" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to retrieve managed identity" -ForegroundColor Red
    exit 1
}

# Step 2: Get AI Services resource ID
Write-Host "`nStep 2: Getting AI Services resource..." -ForegroundColor Yellow
$subscriptionId = az account show --query id -o tsv
$aiServicesScope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.CognitiveServices/accounts/$AiServicesName"
Write-Host "✓ AI Services scope: $aiServicesScope" -ForegroundColor Green

# Step 3: Check current role assignments
Write-Host "`nStep 3: Checking current role assignments..." -ForegroundColor Yellow
$roleAssignments = az role assignment list `
    --scope $aiServicesScope `
    -o json | ConvertFrom-Json

if ($roleAssignments.Count -eq 0) {
    Write-Host "ℹ No role assignments found on AI Services" -ForegroundColor Cyan
}
else {
    Write-Host "Found $($roleAssignments.Count) role assignment(s):" -ForegroundColor Yellow
    foreach ($assignment in $roleAssignments) {
        Write-Host "  - Principal: $($assignment.principalId)" -ForegroundColor Yellow
        Write-Host "    Role: $($assignment.roleDefinitionName)" -ForegroundColor Yellow
        Write-Host "    Type: $($assignment.principalType)" -ForegroundColor Yellow
    }
}

# Step 4: Check if App Service identity already has Cognitive Services User role
Write-Host "`nStep 4: Checking if App Service has Cognitive Services User role..." -ForegroundColor Yellow
$appServiceHasRole = $false
if ($roleAssignments.Count -gt 0) {
    foreach ($assignment in $roleAssignments) {
        if ($assignment.principalId -eq $appServicePrincipalId -and $assignment.roleDefinitionId -like "*$CognitiveServicesUserRoleId*") {
            $appServiceHasRole = $true
            Write-Host "✓ App Service already has Cognitive Services User role!" -ForegroundColor Green
            break
        }
    }
}

if (-not $appServiceHasRole) {
    Write-Host "⚠ App Service does NOT have the correct role" -ForegroundColor Red
    
    # Step 5: Remove any incorrect role assignments (optional cleanup)
    Write-Host "`nStep 5: Removing any incorrect role assignments..." -ForegroundColor Yellow
    $incorrectAssignments = $roleAssignments | Where-Object { $_.principalId -ne $appServicePrincipalId }
    
    if ($incorrectAssignments.Count -gt 0) {
        Write-Host "Found $($incorrectAssignments.Count) incorrect role assignment(s) to remove" -ForegroundColor Yellow
        foreach ($assignment in $incorrectAssignments) {
            Write-Host "Removing: $($assignment.principalName) - $($assignment.roleDefinitionName)" -ForegroundColor Yellow
            $result = az role assignment delete --ids $assignment.id 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Removed: $($assignment.roleDefinitionName) for $($assignment.principalName)" -ForegroundColor Green
            }
            else {
                Write-Host "✗ Failed to remove assignment: $result" -ForegroundColor Red
            }
        }
    }
}

# Step 6: Assign Cognitive Services User role if not already assigned
if (-not $appServiceHasRole) {
    Write-Host "`nStep 6: Assigning Cognitive Services User role to App Service..." -ForegroundColor Yellow
    try {
        az role assignment create `
            --role "Cognitive Services User" `
            --assignee-object-id $appServicePrincipalId `
            --assignee-principal-type ServicePrincipal `
            --scope $aiServicesScope `
            -o none
        
        Write-Host "✓ Successfully assigned Cognitive Services User role" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Failed to assign role: $_" -ForegroundColor Red
        exit 1
    }
}

# Step 7: Final validation
Write-Host "`nStep 7: Final validation..." -ForegroundColor Yellow
$finalAssignments = az role assignment list `
    --scope $aiServicesScope `
    --assignee-object-id $appServicePrincipalId `
    -o json | ConvertFrom-Json

if ($finalAssignments.Count -gt 0 -and ($finalAssignments[0].roleDefinitionName -eq "Cognitive Services User" -or $finalAssignments.roleDefinitionName -eq "Cognitive Services User")) {
    Write-Host "✓ SUCCESS: App Service identity has the correct role!" -ForegroundColor Green
    Write-Host "  Role: Cognitive Services User" -ForegroundColor Green
    Write-Host "  Principal: $appServicePrincipalId" -ForegroundColor Green
    Write-Host "`n✨ Identity-only authentication is now properly configured!" -ForegroundColor Green
}
else {
    Write-Host "✗ VALIDATION FAILED: Role assignment not correct" -ForegroundColor Red
    if ($finalAssignments.Count -eq 0) {
        Write-Host "  No role assignments found for App Service identity" -ForegroundColor Red
    }
    else {
        Write-Host "  Found role: $($finalAssignments[0].roleDefinitionName)" -ForegroundColor Red
    }
    exit 1
}
