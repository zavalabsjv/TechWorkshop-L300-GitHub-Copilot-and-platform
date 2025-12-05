# GitHub Actions CI/CD Workflow Setup

## Overview

The `.github/workflows/build-deploy.yml` workflow automatically builds your .NET application as a Docker container using Azure Container Registry (ACR) and deploys it to your Azure App Service.

**Trigger:** Runs on every push to `dev` or `main` branches, or manually via workflow dispatch.

---

## Required GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions → New repository secret):

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AZURE_CLIENT_ID` | Azure AD app registration client ID (Entra ID) | `12345678-1234-1234-1234-123456789012` |
| `AZURE_TENANT_ID` | Azure AD tenant ID (Entra ID) | `87654321-4321-4321-4321-210987654321` |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID | `abcdef12-abcd-abcd-abcd-abcdefabcdef` |
| `AZURE_REGISTRY_URL` | Full ACR login server URL | `acrzavastorec2tmaeyigsq7w.azurecr.io` |
| `AZURE_REGISTRY_NAME` | ACR registry name (short) | `acrzavastorec2tmaeyigsq7w` |
| `AZURE_APP_SERVICE_NAME` | App Service name | `app-zavastorefront-dev-centralus` |
| `AZURE_RESOURCE_GROUP` | Resource group name | `rg-zavastorefront-dev-centralus` |

---

## Required GitHub Variables

Add these variables to your GitHub repository (Settings → Secrets and variables → Actions → New repository variable):

Currently, none are required. All configuration is in secrets.

---

## How to Set Up Federated Authentication

This workflow uses **OpenID Connect (OIDC)** federated authentication instead of static credentials.

### Step 1: Create an Azure AD App Registration

```bash
az ad app create --display-name "github-zavastorefront-ci" 
# Note the appId (this is AZURE_CLIENT_ID)
```

### Step 2: Create a Service Principal

```bash
az ad sp create --id <appId>
```

### Step 3: Grant App Service Permissions

```bash
# Grant permissions to manage App Service and ACR
az role assignment create \
  --assignee <appId> \
  --role "Contributor" \
  --scope /subscriptions/<subscription-id>/resourceGroups/<resource-group>
```

### Step 4: Create Federated Credentials

```bash
az identity federated-credential create \
  --name "github-zavastorefront" \
  --identity-name <app-registration-name> \
  --issuer "https://token.actions.githubusercontent.com" \
  --subject "repo:<github-org>/<repo-name>:ref:refs/heads/dev"
```

Replace:
- `<app-registration-name>`: Name from Step 1
- `<github-org>`: Your GitHub organization
- `<repo-name>`: Repository name (e.g., `TechWorkshop-L300-GitHub-Copilot-and-platform`)

Repeat for each branch (add subjects for `main`, `dev`, etc.)

### Step 5: Verify Permissions

Verify the app registration has permissions:
```bash
az role assignment list --assignee <appId> --scope /subscriptions/<subscription-id>
```

---

## How to Get Secret Values

### Azure IDs
```bash
# Get Tenant ID
az account show --query "tenantId" -o tsv

# Get Subscription ID
az account show --query "id" -o tsv

# Get Client ID (from app registration)
az ad app list --display-name "github-zavastorefront-ci" --query "[0].appId" -o tsv
```

### ACR Details
```bash
# Get Registry URL and Name
az acr list --resource-group <resource-group> --query "[0].[loginServer, name]" -o tsv
```

### App Service Details
```bash
# Get App Service and Resource Group names
az webapp list --resource-group <resource-group> --query "[0].[name, resourceGroup]" -o tsv
```

**Note:** For container deployments, the `azure/webapps-deploy@v3` action uses the Azure Login context (OIDC federated auth) that's already configured, so no publish profile is needed. The action automatically authenticates through the established Azure session.

---

## Workflow Steps

1. **Checkout**: Clones your repository
2. **Azure Login**: Authenticates using federated OIDC credentials
3. **Build Docker Image**: Uses `az acr build` to build in Azure (no local Docker required)
   - Tags image with `:latest`, `:commit-sha`, and `:branch-name`
   - Automatically pushes to ACR
4. **Deploy to App Service** (only on push to `dev` or `main` branches):
   - Uses official `azure/webapps-deploy@v3` action
   - Updates App Service to pull and run the new container image
   - Authenticates with publish profile
5. **Pull Requests**: Build step runs, but deployment is skipped for validation

---

## Triggering Behavior

| Event | Branch | Build? | Deploy? |
|-------|--------|--------|---------|
| Push | `dev` | ✅ Yes | ✅ Yes |
| Push | `main` | ✅ Yes | ✅ Yes |
| Push | Other | ✅ Yes | ❌ No |
| Pull Request | Any | ✅ Yes | ❌ No |
| Manual Dispatch | Any | ✅ Yes | ❌ No |

---

## Workflow Steps

1. **Checkout**: Clones your repository
2. **Azure Login**: Authenticates using federated OIDC credentials
3. **Build Docker Image**: Uses `az acr build` to build in Azure (no local Docker required)
   - Tags image with `:latest`, `:commit-sha`, and `:branch-name`
   - Automatically pushes to ACR
4. **Deploy to App Service** (only on push to `dev` or `main` branches):
   - Uses official `azure/webapps-deploy@v3` action
   - Updates App Service to pull and run the new container image
   - Authenticates with publish profile
5. **Pull Requests**: Build step runs, but deployment is skipped for validation

---

## Triggering Behavior

| Event | Branch | Build? | Deploy? |
|-------|--------|--------|---------|
| Push | `dev` | ✅ Yes | ✅ Yes |
| Push | `main` | ✅ Yes | ✅ Yes |
| Push | Other | ✅ Yes | ❌ No |
| Pull Request | Any | ✅ Yes | ❌ No |
| Manual Dispatch | Any | ✅ Yes | ❌ No |

---

## Testing the Workflow

### Manual Trigger
Go to **Actions** → **Build and Deploy to Azure App Service** → **Run workflow** → Select branch → **Run**

### Push Trigger
```bash
git push origin dev
```
The workflow will automatically start.

### Monitor Workflow
1. Go to **Actions** tab in GitHub
2. Click on the workflow run
3. View logs for each step

---

## Troubleshooting

### Authentication Failed
- Verify federated credential is created correctly
- Check app registration has permissions on resource group
- Ensure secrets match exactly (no spaces, typos)

### Image Build Failed
- Check Dockerfile at `src/Dockerfile` exists and is valid
- Review ACR build logs: `az acr build --registry <name> --file src/Dockerfile src/`

### App Service Deployment Failed
- Verify App Service name and resource group are correct
- Check app service is not in a failed state: `az webapp show --name <app> --resource-group <rg>`
- Review app service logs: `az webapp log tail --name <app> --resource-group <rg>`

---

## Cost Considerations

- **ACR Build**: Charged per build minute (usually < $1/month for small projects)
- **GitHub Actions**: Free tier includes 2,000 minutes/month
- **App Service**: F1 Free tier (included in your deployment)

---

## Security Notes

✅ **Good Practices Used:**
- Federated authentication (no static credentials stored)
- Managed identity for container pull from ACR
- Least-privilege RBAC roles
- Secrets stored in GitHub (not in code)

⚠️ **Important:**
- Federated credentials expire after 6 months - refresh periodically
- Monitor workflow logs for failed deployments
- Review and audit role assignments regularly
