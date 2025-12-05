#!/usr/bin/env pwsh
<#
.SYNOPSIS
  Quick fix: Set AZURE_CLIENT_ID environment variable on App Service
  
.DESCRIPTION
  This script immediately sets the AZURE_CLIENT_ID app setting on the running App Service
  without waiting for a full deployment. This allows DefaultAzureCredential to find the 
  user-assigned managed identity when running in the container.
  
.NOTES
  This is a temporary fix while the Bicep template updates are being deployed.
  The Bicep deployment will make this permanent.
#>

param(
    [string]$appName = "app-zavastorefront-dev-centralus",
    [string]$resourceGroup = "rg-zavastorefront-dev-centralus",
    [string]$clientId = "76d577c1-60bc-4d7b-b524-75d4386cdde0"
)

Write-Host "🔧 Setting AZURE_CLIENT_ID environment variable for managed identity..." -ForegroundColor Cyan

try {
    # Verify app exists
    Write-Host "  1. Verifying App Service exists..."
    $app = az webapp show --name $appName --resource-group $resourceGroup --query "name" -o tsv
    if (-not $app) {
        throw "App Service '$appName' not found in resource group '$resourceGroup'"
    }
    Write-Host "     ✓ Found: $app"
    
    # Set the app setting
    Write-Host "  2. Setting AZURE_CLIENT_ID='$clientId'..."
    az webapp config appsettings set `
        --name $appName `
        --resource-group $resourceGroup `
        --settings AZURE_CLIENT_ID=$clientId `
        --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "     ✓ AZURE_CLIENT_ID set successfully"
    } else {
        throw "Failed to set app setting"
    }
    
    # Verify it was set
    Write-Host "  3. Verifying the setting..."
    $setting = az webapp config appsettings list `
        --name $appName `
        --resource-group $resourceGroup `
        --query "[?name=='AZURE_CLIENT_ID'].value" -o tsv
    
    if ($setting -eq $clientId) {
        Write-Host "     ✓ Verified: AZURE_CLIENT_ID=$setting"
    } else {
        throw "Verification failed - setting not applied correctly"
    }
    
    # Restart the app
    Write-Host "  4. Restarting App Service to apply changes..."
    az webapp restart --name $appName --resource-group $resourceGroup --output none
    
    Write-Host "     ✓ App Service restarted"
    
    Write-Host ""
    Write-Host "✅ SUCCESS: AZURE_CLIENT_ID has been set and App Service restarted!" -ForegroundColor Green
    Write-Host ""
    Write-Host "What this fixes:"
    Write-Host "  • DefaultAzureCredential now knows which managed identity to use"
    Write-Host "  • 'Unable to load the proper Managed Identity' error should be resolved"
    Write-Host "  • Chat feature should now work with managed identity authentication"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Wait 30-60 seconds for the app to restart"
    Write-Host "  2. Navigate to: https://$($appName).azurewebsites.net/chat"
    Write-Host "  3. Send a test message to verify the fix"
    Write-Host ""
    
} catch {
    Write-Host "❌ ERROR: $_" -ForegroundColor Red
    exit 1
}
