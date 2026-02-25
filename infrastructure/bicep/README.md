# GA4GH TES Infrastructure - Bicep Deployment Guide

## Overview

This directory contains Infrastructure as Code (IaC) templates for deploying the GA4GH Task Execution Service (TES) infrastructure on Microsoft Azure using Bicep. The templates provision a complete, production-ready environment including compute, storage, networking, monitoring, and security components.

## Architecture

The TES infrastructure consists of the following Azure resources:

### Core Compute
- **Azure Kubernetes Service (AKS)**: Orchestrates TES service containers
- **Azure Batch**: Provides scalable compute for task execution
- **PostgreSQL Flexible Server**: Database for TES metadata and state

### Storage & Registry
- **Azure Storage Account**: Blob storage for input/output data and configuration
- **Azure Container Registry (ACR)**: Private registry for TES container images

### Networking
- **Virtual Network (VNet)**: Isolated network environment with three subnets:
  - VM/AKS Subnet (10.1.0.0/24)
  - PostgreSQL Delegated Subnet (10.1.1.0/24)
  - Batch Nodes Subnet (10.1.128.0/17)
- **Network Security Groups (NSGs)**: Firewall rules for traffic control
- **Private DNS Zones**: DNS resolution for private endpoints (optional)

### Security & Identity
- **User-Assigned Managed Identity**: Identity for accessing Azure resources
- **Azure Key Vault**: Secure storage for secrets and certificates
- **RBAC Role Assignments**: Least-privilege access control

### Monitoring & Observability
- **Log Analytics Workspace**: Centralized logging
- **Application Insights**: Application performance monitoring (APM)

## Prerequisites

Before deploying, ensure you have:

1. **Azure CLI** (version 2.50.0 or later)
   ```powershell
   az --version
   ```

2. **Bicep CLI** (included with Azure CLI 2.20.0+)
   ```powershell
   az bicep version
   ```

3. **Azure Subscription** with appropriate permissions:
   - `Owner` or `User Access Administrator` (for RBAC assignments)
   - `Contributor` (for resource creation)

4. **Authentication**
   ```powershell
   az login
   az account set --subscription "<subscription-id>"
   ```

## Quick Start

### 1. Clone the Repository
```powershell
git clone https://github.com/your-org/ga4gh-tes.git
cd ga4gh-tes/infrastructure/bicep
```

### 2. Customize Parameters

Copy the example parameter file and modify it for your environment:

```powershell
# For development
cp parameters.dev.json parameters.custom.json

# For production
cp parameters.prod.example.json parameters.prod.json
```

Edit the parameter file with your specific values:
```json
{
  "parameters": {
    "mainIdentifierPrefix": {
      "value": "myorg-tes"
    },
    "location": {
      "value": "eastus"
    },
    "postgreSqlAdministratorPassword": {
      "value": "YourSecurePassword123!"
    }
  }
}
```

### 3. Validate the Deployment

```powershell
az deployment sub validate `
  --location eastus `
  --template-file main.bicep `
  --parameters @parameters.custom.json
```

### 4. Deploy the Infrastructure

```powershell
az deployment sub create `
  --name "tes-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')" `
  --location eastus `
  --template-file main.bicep `
  --parameters @parameters.custom.json
```

Expected deployment time: **15-25 minutes**

### 5. Retrieve Deployment Outputs

```powershell
$outputs = az deployment sub show `
  --name tes-deployment-<timestamp> `
  --query properties.outputs `
  --output json | ConvertFrom-Json

Write-Host "Resource Group: $($outputs.resourceGroupName.value)"
Write-Host "AKS Cluster: $($outputs.aksClusterName.value)"
Write-Host "Storage Account: $($outputs.storageAccountName.value)"
Write-Host "Key Vault URI: $($outputs.keyVaultUri.value)"
```

## Parameter Reference

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `mainIdentifierPrefix` | string | Prefix for all resource names (e.g., "tes-prod") |
| `location` | string | Azure region (e.g., "eastus", "westus2") |
| `postgreSqlAdministratorLogin` | string | PostgreSQL admin username |
| `postgreSqlAdministratorPassword` | securestring | PostgreSQL admin password (min 8 chars) |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `deploymentEnvironment` | string | "development" | Environment type (dev/staging/prod) |
| `resourceGroupName` | string | auto-generated | Custom resource group name |
| `vnetAddressSpace` | string | "10.1.0.0/16" | VNet address space |
| `aksPoolSize` | int | 3 | Number of AKS nodes |
| `aksVmSize` | string | "Standard_D4s_v3" | AKS node VM size |
| `postgreSqlSkuName` | string | "Standard_D2ds_v4" | PostgreSQL SKU |
| `postgreSqlTier` | string | "GeneralPurpose" | PostgreSQL tier |
| `postgreSqlStorageSize` | int | 128 | PostgreSQL storage in GB |
| `enablePrivateNetworking` | bool | false | Enable private endpoints/networking |
| `aadGroupIds` | array | [] | Azure AD group IDs for AKS admin access |

See [main.bicep](main.bicep) for a complete list of parameters.

## Module Structure

```
bicep/
├── main.bicep                      # Main orchestration template
├── parameters.dev.json             # Development parameters
├── parameters.prod.example.json    # Production parameters (example)
└── modules/
    ├── networking.bicep            # VNet, subnets, NSGs
    ├── identity.bicep              # Managed identity
    ├── logAnalytics.bicep          # Log Analytics workspace
    ├── appInsights.bicep           # Application Insights
    ├── storage.bicep               # Storage account with containers
    ├── postgresql.bicep            # PostgreSQL Flexible Server
    ├── batch.bicep                 # Azure Batch account
    ├── aks.bicep                   # AKS cluster
    ├── keyVault.bicep              # Azure Key Vault
    ├── acr.bicep                   # Azure Container Registry
    └── roleAssignments.bicep       # RBAC role assignments
```

## Post-Deployment Configuration

### 1. Configure AKS Access

```powershell
$rgName = "<resource-group-name>"
$aksName = "<aks-cluster-name>"

az aks get-credentials --resource-group $rgName --name $aksName
kubectl get nodes
```

### 2. Push TES Images to ACR

```powershell
$acrName = "<acr-name>"
az acr login --name $acrName

# Build and push TES image
cd ../../src
docker build -t $acrName.azurecr.io/tes:latest -f Dockerfile-Tes .
docker push $acrName.azurecr.io/tes:latest
```

### 3. Configure PostgreSQL Database

Connect to PostgreSQL and initialize the TES database schema:

```powershell
$pgServer = "<postgresql-server-name>.postgres.database.azure.com"
$pgUser = "<admin-username>"
$pgDb = "tes_db"

psql "host=$pgServer port=5432 dbname=$pgDb user=$pgUser sslmode=require"
```

### 4. Deploy TES to AKS

Apply Kubernetes manifests (assuming you have these in your repository):

```powershell
kubectl apply -f ../kubernetes/tes-deployment.yaml
kubectl apply -f ../kubernetes/tes-service.yaml
```

### 5. Verify Deployment

```powershell
kubectl get pods -n default
kubectl get services -n default
kubectl logs -l app=tes --tail=50
```

## Security Considerations

### Secrets Management

**Never commit secrets to version control!**

For production deployments, store secrets in Azure Key Vault:

```powershell
$kvName = "<key-vault-name>"
az keyvault secret set --vault-name $kvName --name postgresql-admin-password --value "YourSecurePassword"
```

Reference secrets in parameter files:
```json
{
  "postgreSqlAdministratorPassword": {
    "reference": {
      "keyVault": {
        "id": "/subscriptions/.../vaults/mykeyvault"
      },
      "secretName": "postgresql-admin-password"
    }
  }
}
```

### Network Security

- **Development**: Leave `enablePrivateNetworking = false` for easier access
- **Production**: Set `enablePrivateNetworking = true` to enable:
  - Private endpoints for Storage, PostgreSQL, Key Vault
  - Private AKS cluster
  - Network isolation via service endpoints

### RBAC Configuration

The deployment automatically assigns these roles to the managed identity:
- **Storage Blob Data Owner** - Full access to storage containers
- **Contributor** - Batch and Application Insights management
- **AcrPull** - Pull images from Container Registry
- **Key Vault Secrets Officer** - Manage Key Vault secrets

Additional users/groups can be granted access via Azure AD:
```powershell
az role assignment create `
  --assignee "<user-or-group-object-id>" `
  --role "Contributor" `
  --scope "/subscriptions/.../resourceGroups/tes-rg"
```

## Cost Optimization

### Development Environment
- Use smaller SKUs: `Standard_B2s` for PostgreSQL, `Standard_D2s_v3` for AKS
- Reduce AKS node count: `aksPoolSize = 1`
- Use `Burstable` tier for PostgreSQL
- Disable auto-scaling features

### Production Environment
- Enable auto-scaling for AKS node pool
- Use `GeneralPurpose` tier for PostgreSQL with appropriate storage
- Configure lifecycle policies for blob storage
- Enable Azure Hybrid Benefit if applicable

### Cost Monitoring
```powershell
# View cost analysis
az consumption usage list --start-date 2024-01-01 --end-date 2024-01-31
```

## Troubleshooting

### Common Issues

#### 1. Deployment Fails with RBAC Errors
**Problem**: Insufficient permissions to assign roles

**Solution**: Ensure your account has `Owner` or `User Access Administrator` role:
```powershell
az role assignment create `
  --assignee "<your-user-id>" `
  --role "Owner" `
  --scope "/subscriptions/<subscription-id>"
```

#### 2. Resource Name Conflicts
**Problem**: Resource names already exist

**Solution**: Change `mainIdentifierPrefix` parameter to generate unique names

#### 3. AKS Deployment Fails
**Problem**: Quota limits exceeded

**Solution**: Check and request quota increases:
```powershell
az vm list-usage --location eastus --output table
```

#### 4. Private Networking Issues
**Problem**: Cannot access resources after enabling private networking

**Solution**: Ensure you're connecting from within the VNet or via VPN/ExpressRoute

### Debug Mode

Enable detailed logging during deployment:
```powershell
az deployment sub create \
  --parameters debugLogging=true \
  --verbose
```

### Validation

Verify resource deployment:
```powershell
$rgName = "<resource-group-name>"

# List all resources
az resource list --resource-group $rgName --output table

# Check AKS status
az aks show --name <aks-name> --resource-group $rgName --query provisioningState

# Check Batch status
az batch account show --name <batch-name> --resource-group $rgName --query provisioningState
```

## Clean Up

To delete all resources:

```powershell
$rgName = "<resource-group-name>"

# WARNING: This will delete ALL resources in the resource group
az group delete --name $rgName --yes --no-wait
```

## Migration from C# Deployer

If you're migrating from the legacy C# deployment tool (`deploy-tes-on-azure`):

### Configuration Mapping

| C# Configuration Property | Bicep Parameter |
|---------------------------|-----------------|
| `DeploymentOrganizationName` | `mainIdentifierPrefix` |
| `ResourceGroupName` | `resourceGroupName` |
| `VnetAddressSpace` | `vnetAddressSpace` |
| `PostgreSqlServerName` | Auto-generated from prefix |
| `PostgreSqlAdministratorLogin` | `postgreSqlAdministratorLogin` |
| `PostgreSqlAdministratorPassword` | `postgreSqlAdministratorPassword` |
| `AksPoolSize` | `aksPoolSize` |
| `BatchAccountName` | Auto-generated from prefix |
| `StorageAccountName` | Auto-generated from prefix |

### Parameter Extraction

Extract parameters from existing C# configuration:

```powershell
# Review current C# deployer configuration
cat src/deploy-tes-on-azure/samples/config.json

# Map to Bicep parameters
# Example: DeploymentOrganizationName -> mainIdentifierPrefix
```

### Key Differences

1. **Resource Naming**: Bicep auto-generates names with unique suffixes
2. **Security**: Bicep uses RBAC instead of access keys where possible
3. **Networking**: Private networking is optional (toggle with `enablePrivateNetworking`)
4. **Identity**: Uses user-assigned managed identity for all service authentication

## Support & Contribution

- **Issues**: Report bugs at [GitHub Issues](https://github.com/your-org/ga4gh-tes/issues)
- **Documentation**: See [main README](../../README.md)
- **Contributing**: Follow [CONTRIBUTING.md](../../CONTRIBUTING.md)
- **Security**: Report vulnerabilities via [SECURITY.md](../../SECURITY.md)

## Additional Resources

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [GA4GH TES API Specification](https://github.com/ga4gh/task-execution-schemas)
- [Azure AKS Best Practices](https://learn.microsoft.com/azure/aks/best-practices)
- [Azure Batch Documentation](https://learn.microsoft.com/azure/batch/)
- [Azure PostgreSQL Flexible Server](https://learn.microsoft.com/azure/postgresql/flexible-server/)

## License

This project is licensed under the [LICENSE](../../LICENSE) terms.

---

**Last Updated**: January 2025  
**Bicep Version**: 0.28.1  
**Minimum Azure CLI**: 2.50.0
