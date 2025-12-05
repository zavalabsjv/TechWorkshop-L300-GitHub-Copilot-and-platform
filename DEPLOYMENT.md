# ZavaStorefront Azure Deployment Guide

## 🚀 Quick Start

This guide will help you deploy the ZavaStorefront application infrastructure to Azure.

### ✅ Prerequisites Checklist

- [ ] Azure subscription with Owner or Contributor access
- [ ] [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) installed
- [ ] [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
- [ ] PowerShell 7+ (for Windows) or Bash (for Linux/Mac)

### 📦 Deployment Steps

#### 1. Clone and Navigate

```powershell
cd TechWorkshop-L300-GitHub-Copilot-and-platform
```

#### 2. Login to Azure

```powershell
azd auth login
```

#### 3. Initialize Environment

```powershell
# Initialize AZD (first time only)
azd init

# You'll be prompted for:
# - Environment name (e.g., 'dev')
# - Azure subscription
# - Azure region (use 'westus3')
```

#### 4. Provision Infrastructure

```powershell
# Deploy all Azure resources
azd provision
```

This will create:
- ✅ Resource Group in westus3
- ✅ Azure Container Registry with RBAC
- ✅ Managed Identity for secure access
- ✅ Application Insights for monitoring
- ✅ AI Foundry workspace for GPT-4/Phi models
- ✅ Linux App Service Plan
- ✅ Web App for hosting

**Expected time**: 10-15 minutes

#### 5. Build and Deploy Application

```powershell
# Get environment values
azd env get-values

# Build Docker image and deploy
azd deploy
```

#### 6. Verify Deployment

```powershell
# Get the web app URL
azd env get-values | Select-String "WEB_APP_URL"

# Open in browser
$url = azd env get-values | Select-String "WEB_APP_URL" | ForEach-Object { $_ -replace '.*="(.*)"', '$1' }
Start-Process $url
```

### 🔧 Alternative: Manual Deployment

If you prefer to deploy without AZD:

```powershell
# 1. Login
az login

# 2. Set subscription
az account set --subscription "<your-subscription-id>"

# 3. Deploy infrastructure
az deployment sub create \
  --name zavastorefront-deployment \
  --location westus3 \
  --template-file ./infra/main.bicep \
  --parameters environmentName=dev location=westus3

# 4. Build and push Docker image
$ACR_NAME = "<your-acr-name>"
az acr login --name $ACR_NAME
cd src
docker build -t $ACR_NAME.azurecr.io/zavastorefront:latest .
docker push $ACR_NAME.azurecr.io/zavastorefront:latest

# 5. Update web app with image
az webapp config container set \
  --name app-zavastorefront-dev-westus3 \
  --resource-group rg-zavastorefront-dev-westus3 \
  --docker-custom-image-name $ACR_NAME.azurecr.io/zavastorefront:latest
```

### 📊 Post-Deployment

#### Access Azure Resources

```powershell
# Get all environment values
azd env get-values

# Open Azure Portal to resource group
az group show --name rg-zavastorefront-dev-westus3 --query id --output tsv | ForEach-Object { Start-Process "https://portal.azure.com/#@/resource$_" }
```

#### View Application Insights

1. Navigate to Azure Portal
2. Go to your Resource Group
3. Open Application Insights resource
4. View Live Metrics, Performance, Logs

#### Configure AI Models in AI Foundry

1. Open [Azure AI Studio](https://ai.azure.com)
2. Select your project
3. Deploy models:
   - GPT-4 (for advanced scenarios)
   - Phi-3 (for efficient inference)

### 🧪 Testing

```powershell
# Test the web application
$url = azd env get-values | Select-String "WEB_APP_URL" | ForEach-Object { $_ -replace '.*="(.*)"', '$1' }
Invoke-WebRequest -Uri $url -UseBasicParsing

# Check logs
az webapp log tail --name app-zavastorefront-dev-westus3 --resource-group rg-zavastorefront-dev-westus3
```

### 🔄 Update Infrastructure

```powershell
# After modifying Bicep files
azd provision

# Redeploy application
azd deploy

# Or do both
azd up
```

### 🧹 Cleanup

When you're done, remove all resources:

```powershell
# Complete cleanup
azd down --purge

# Or manually delete resource group
az group delete --name rg-zavastorefront-dev-westus3 --yes --no-wait
```

### 🐛 Common Issues

#### Issue: "azd: command not found"

**Solution**: Install Azure Developer CLI
```powershell
# Windows (PowerShell)
winget install microsoft.azd

# macOS
brew tap azure/azd && brew install azd

# Linux
curl -fsSL https://aka.ms/install-azd.sh | bash
```

#### Issue: ACR authentication fails

**Solution**: Ensure managed identity has proper permissions
```powershell
# Check role assignments
$identityId = azd env get-values | Select-String "MANAGED_IDENTITY_CLIENT_ID" | ForEach-Object { $_ -replace '.*="(.*)"', '$1' }
az role assignment list --assignee $identityId
```

#### Issue: Application not starting

**Solution**: Check container logs
```powershell
az webapp log tail --name app-zavastorefront-dev-westus3 --resource-group rg-zavastorefront-dev-westus3
```

### 📚 Next Steps

- [ ] Configure CI/CD pipeline with GitHub Actions
- [ ] Set up additional environments (staging, production)
- [ ] Configure custom domain and SSL
- [ ] Enable autoscaling rules
- [ ] Set up alerts and monitoring dashboards
- [ ] Implement Azure Key Vault for secrets management

### 📖 Documentation

For detailed documentation, see:
- [Infrastructure README](./infra/README.md)
- [Azure Developer CLI Docs](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

### 🤝 Support

For issues related to:
- **Infrastructure**: Check the [infra/README.md](./infra/README.md)
- **Application**: See the [src/README.md](./src/README.md)
- **Azure Services**: Consult [Azure Documentation](https://docs.microsoft.com/azure/)

---

**Happy Deploying! 🎉**
