# ZavaStorefront Azure Infrastructure

This directory contains the Infrastructure as Code (IaC) for deploying the ZavaStorefront application to Azure using Bicep and Azure Developer CLI (AZD).

## 📋 Architecture Overview

The infrastructure deploys the following Azure resources:

- **Resource Group**: Container for all resources in westus3
- **Azure Container Registry (ACR)**: Stores Docker images with RBAC-based access
- **Managed Identity**: Enables secure, passwordless authentication
- **Log Analytics Workspace**: Centralized logging and monitoring
- **Application Insights**: Application performance monitoring
- **AI Foundry (Azure AI Studio)**: For GPT-4 and Phi model deployment
- **App Service Plan**: Linux-based compute for container hosting
- **App Service**: Hosts the containerized .NET 6.0 application

## 🔐 Security Features

- **No Admin Credentials**: ACR uses Azure RBAC instead of admin passwords
- **Managed Identity**: App Service authenticates to ACR using managed identity
- **HTTPS Only**: All web traffic enforced over HTTPS
- **TLS 1.2**: Minimum TLS version enforced
- **Key Vault Integration**: AI Foundry uses Key Vault for secrets

## 📁 Directory Structure

```
infra/
├── main.bicep                      # Main orchestration template
├── main.parameters.json            # Parameter file with environment variables
└── modules/
    ├── managed-identity.bicep      # User-assigned managed identity
    ├── monitoring.bicep            # Log Analytics + Application Insights
    ├── container-registry.bicep    # ACR with RBAC configuration
    ├── ai-foundry.bicep           # Azure AI Studio workspace
    ├── app-service-plan.bicep     # Linux App Service Plan
    └── web-app.bicep              # Containerized web application
```

## 🚀 Prerequisites

1. **Azure CLI**: Install from [here](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **Azure Developer CLI (AZD)**: Install from [here](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
3. **Docker** (optional): Only needed for local builds
4. **Azure Subscription**: With appropriate permissions

## 🛠️ Deployment Steps

### Option 1: Using Azure Developer CLI (Recommended)

```powershell
# 1. Login to Azure
azd auth login

# 2. Initialize the environment (first time only)
azd init

# 3. Provision infrastructure and deploy application
azd up

# Or provision and deploy separately:
azd provision  # Deploy infrastructure
azd deploy     # Deploy application
```

### Option 2: Using Azure CLI

```powershell
# 1. Login to Azure
az login

# 2. Set your subscription
az account set --subscription "<your-subscription-id>"

# 3. Create deployment
az deployment sub create \
  --name zavastorefront-deployment \
  --location westus3 \
  --template-file ./infra/main.bicep \
  --parameters environmentName=dev location=westus3
```

## 🔧 Configuration

### Environment Variables

Create a `.azure/<env-name>/.env` file with:

```env
AZURE_ENV_NAME=dev
AZURE_LOCATION=westus3
AZURE_SUBSCRIPTION_ID=<your-subscription-id>
```

### Application Settings

The following environment variables are automatically configured in the App Service:

| Variable | Description |
|----------|-------------|
| `DOCKER_REGISTRY_SERVER_URL` | ACR login server URL |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Application Insights connection |
| `AI_FOUNDRY_ENDPOINT` | Azure AI Studio endpoint |
| `AI_FOUNDRY_PROJECT_ID` | Azure AI Studio project ID |

## 📦 Building and Pushing Docker Image

```powershell
# Get ACR login server from outputs
$ACR_NAME = azd env get-values | Select-String "AZURE_CONTAINER_REGISTRY_NAME" | ForEach-Object { $_ -replace '.*="(.*)"', '$1' }

# Login to ACR (using managed identity)
az acr login --name $ACR_NAME

# Build and push image
cd src
docker build -t $ACR_NAME.azurecr.io/zavastorefront:latest .
docker push $ACR_NAME.azurecr.io/zavastorefront:latest
```

## 🔍 Monitoring

### Application Insights

Access Application Insights from Azure Portal:
1. Navigate to your resource group
2. Open Application Insights resource
3. View Live Metrics, Performance, Failures, etc.

### Log Analytics

Query logs using Kusto Query Language (KQL):
```kql
AppServiceConsoleLogs
| where TimeGenerated > ago(1h)
| project TimeGenerated, ResultDescription
| order by TimeGenerated desc
```

## 🤖 AI Foundry Integration

### Deploying Models

1. Navigate to Azure AI Studio portal
2. Select your project
3. Deploy models:
   - **GPT-4**: For advanced language understanding
   - **Phi-3**: For efficient edge deployment

### Accessing from Application

Use the environment variables configured in App Service:
- `AI_FOUNDRY_ENDPOINT`
- `AI_FOUNDRY_PROJECT_ID`

## 🧹 Cleanup

To delete all resources:

```powershell
# Using AZD
azd down --purge

# Using Azure CLI
az group delete --name rg-zavastorefront-dev-westus3 --yes
```

## 📊 Resource Naming Convention

| Resource Type | Naming Pattern | Example |
|--------------|----------------|---------|
| Resource Group | `rg-zavastorefront-{env}-{location}` | `rg-zavastorefront-dev-westus3` |
| Container Registry | `acrzavastore{uniquestring}` | `acrzavastoreabc123` |
| App Service Plan | `asp-zavastorefront-{env}-{location}` | `asp-zavastorefront-dev-westus3` |
| Web App | `app-zavastorefront-{env}-{location}` | `app-zavastorefront-dev-westus3` |
| App Insights | `appi-zavastorefront-{env}-{location}` | `appi-zavastorefront-dev-westus3` |
| Log Analytics | `law-zavastorefront-{env}-{location}` | `law-zavastorefront-dev-westus3` |
| AI Foundry | `aif-zavastorefront-{env}-{location}` | `aif-zavastorefront-dev-westus3` |
| Managed Identity | `id-zavastorefront-{env}-{location}` | `id-zavastorefront-dev-westus3` |

## 🐛 Troubleshooting

### Issue: ACR Pull Fails

**Solution**: Verify managed identity has AcrPull role:
```powershell
az role assignment list --assignee <managed-identity-principal-id> --scope <acr-resource-id>
```

### Issue: Application Insights Not Receiving Data

**Solution**: Check connection string in App Service configuration:
```powershell
az webapp config appsettings list --name <app-name> --resource-group <rg-name>
```

### Issue: AI Foundry Connection Failed

**Solution**: Verify AI Services connection in Azure AI Studio portal

## 📚 Additional Resources

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure App Service for Containers](https://learn.microsoft.com/azure/app-service/tutorial-custom-container)
- [Azure AI Studio Documentation](https://learn.microsoft.com/azure/ai-studio/)
- [Application Insights for .NET](https://learn.microsoft.com/azure/azure-monitor/app/asp-net-core)

## 🤝 Contributing

Please refer to the main repository README for contribution guidelines.

## 📄 License

See the main repository LICENSE file for details.
