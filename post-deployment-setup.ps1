# Post-Deployment Setup Script
# This script completes the configuration after azd provision
# Specifically, it assigns the Cognitive Services User role to the managed identity

param(
    [string]$ResourceGroup = "rg-zavastorefront-dev-centralus",
    [string]$EnvironmentName = "dev",
    [string]$Location = "centralus"
)

Write-Host "🔧 Post-Deployment Setup for AI Foundry" -ForegroundColor Cyan

# Get the managed identity
Write-Host "`n1️⃣  Finding managed identity..." -ForegroundColor Blue
$identityName = "id-zavastorefront-${EnvironmentName}-${Location}"
$identityJson = az identity show --name $identityName --resource-group $ResourceGroup
$identity = $identityJson | ConvertFrom-Json

if (-not $identity) {
    Write-Host "❌ ERROR: Could not find managed identity: $identityName" -ForegroundColor Red
    exit 1
}

# Extract principal ID from response
$principalId = if ($identity.principalId) { $identity.principalId } else { $identity.properties.principalId }

if (-not $principalId) {
    Write-Host "❌ ERROR: Could not retrieve principal ID from managed identity" -ForegroundColor Red
    Write-Host "   Response: $identityJson" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Found managed identity: $identityName" -ForegroundColor Green
Write-Host "  Principal ID: $principalId"

# Get the AI Services resource
Write-Host "`n2️⃣  Finding AI Services resource..." -ForegroundColor Blue
$aiServices = az cognitiveservices account list --resource-group $ResourceGroup --query "[?contains(name, 'aif')]" | ConvertFrom-Json

if (-not $aiServices -or $aiServices.Count -eq 0) {
    Write-Host "❌ ERROR: Could not find AI Services resource" -ForegroundColor Red
    exit 1
}

$aiServicesId = $aiServices[0].id
$aiServicesName = $aiServices[0].name
Write-Host "✓ Found AI Services: $aiServicesName" -ForegroundColor Green

# Assign Cognitive Services User role
Write-Host "`n3️⃣  Assigning Cognitive Services User role..." -ForegroundColor Blue
try {
    az role assignment create `
        --role "Cognitive Services User" `
        --assignee-object-id $principalId `
        --scope $aiServicesId `
        --output none
    
    Write-Host "✓ Role assignment created successfully" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Role assignment may already exist or could not be created" -ForegroundColor Yellow
    Write-Host "   Error: $_"
}

# Verify the role assignment
Write-Host "`n4️⃣  Verifying role assignment..." -ForegroundColor Blue
$assignments = az role assignment list `
    --assignee-object-id $principalId `
    --scope $aiServicesId | ConvertFrom-Json

if ($assignments -and $assignments.Count -gt 0) {
    Write-Host "✓ Role assignment verified" -ForegroundColor Green
    $assignments | ForEach-Object {
        Write-Host "  - Role: $($_.roleDefinitionName)" -ForegroundColor Green
    }
}
else {
    Write-Host "⚠️  Could not verify role assignment" -ForegroundColor Yellow
}

# Summary
Write-Host "`n" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✅ POST-DEPLOYMENT SETUP COMPLETE" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Cyan

Write-Host "`n📋 Configuration Summary:" -ForegroundColor Blue
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Managed Identity: $identityName"
Write-Host "  Principal ID: $principalId"
Write-Host "  AI Services: $aiServicesName"
Write-Host "  Role: Cognitive Services User"

Write-Host "`n🚀 Next Steps:" -ForegroundColor Blue
Write-Host "  1. Deploy the application: azd deploy"
Write-Host "  2. Test the chat feature"
Write-Host "  3. Check logs in Log Analytics workspace"
Write-Host "  4. Query: AzureDiagnostics | where ResourceProvider =~ `"MICROSOFT.COGNITIVESERVICES`" | sort by TimeGenerated desc"
