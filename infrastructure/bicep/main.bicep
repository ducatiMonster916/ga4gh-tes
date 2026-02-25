// =============================================================================
// GA4GH TES on Azure - Main Bicep Template
// =============================================================================
// This template deploys the complete infrastructure for GA4GH Task Execution Service
// on Azure, including AKS, PostgreSQL, Batch, Storage, and supporting services.

targetScope = 'subscription'

// =============================================================================
// PARAMETERS
// =============================================================================

@description('The Azure region where resources will be deployed')
param location string = deployment().location

@description('Main identifier prefix for resource naming (3-15 characters)')
@minLength(3)
@maxLength(15)
param mainIdentifierPrefix string = 'tes'

@description('Resource group name. If not provided, will be auto-generated.')
param resourceGroupName string = ''

@description('Tags to apply to all resources')
param tags object = {}

// Network Configuration
@description('Virtual network address space')
param vnetAddressSpace string = '10.1.0.0/16'

@description('VM/AKS subnet address space')
param vmSubnetAddressSpace string = '10.1.0.0/24'

@description('PostgreSQL subnet address space')
param postgreSqlSubnetAddressSpace string = '10.1.1.0/24'

@description('Batch nodes subnet address space')
param batchNodesSubnetAddressSpace string = '10.1.128.0/17'

@description('Kubernetes service CIDR')
param kubernetesServiceCidr string = '10.1.4.0/22'

@description('Kubernetes DNS service IP')
param kubernetesDnsServiceIP string = '10.1.4.10'

// PostgreSQL Configuration
@description('PostgreSQL administrator username')
param postgreSqlAdministratorLogin string = 'tes_admin'

@description('PostgreSQL administrator password. If not provided, will be auto-generated.')
@secure()
param postgreSqlAdministratorPassword string = ''

@description('PostgreSQL database name')
param postgreSqlDatabaseName string = 'tes_db'

@description('PostgreSQL SKU name')
param postgreSqlSkuName string = 'Standard_B2s'

@description('PostgreSQL tier')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param postgreSqlTier string = 'Burstable'

@description('PostgreSQL version')
@allowed(['11', '12', '13', '14', '15', '16'])
param postgreSqlVersion string = '14'

@description('PostgreSQL storage size in GiB')
param postgreSqlStorageSize int = 128

// AKS Configuration
@description('AKS cluster node pool size')
param aksPoolSize int = 2

@description('AKS cluster VM size')
param aksVmSize string = 'Standard_D4s_v3'

@description('AKS Kubernetes version. Leave empty for latest stable version.')
param kubernetesVersion string = ''

// Storage Configuration
@description('Storage account name. If not provided, will be auto-generated.')
param storageAccountName string = ''

// Batch Account Configuration
@description('Batch account name. If not provided, will be auto-generated.')
param batchAccountName string = ''

// Application Insights Configuration
@description('Application Insights name. If not provided, will be auto-generated.')
param appInsightsName string = ''

// Key Vault Configuration
@description('Key Vault name. If not provided, will be auto-generated.')
param keyVaultName string = ''

// Networking Options
@description('Enable private networking (private endpoints, disable public access)')
param enablePrivateNetworking bool = false

@description('Azure AD group IDs for RBAC (comma-separated)')
param aadGroupIds string = ''

// Deployment Configuration
@description('Deployment environment (e.g., dev, staging, prod)')
param deploymentEnvironment string = 'production'

// =============================================================================
// VARIABLES
// =============================================================================

var uniqueSuffix = uniqueString(subscription().subscriptionId, location, mainIdentifierPrefix)
var finalResourceGroupName = !empty(resourceGroupName) ? resourceGroupName : '${mainIdentifierPrefix}-${uniqueSuffix}-rg'
var finalStorageAccountName = !empty(storageAccountName) ? storageAccountName : take(replace('${mainIdentifierPrefix}${uniqueSuffix}', '-', ''), 24)
var finalBatchAccountName = !empty(batchAccountName) ? batchAccountName : take('${mainIdentifierPrefix}${uniqueSuffix}', 24)
var finalAppInsightsName = !empty(appInsightsName) ? appInsightsName : '${mainIdentifierPrefix}-${uniqueSuffix}-ai'
var finalKeyVaultName = !empty(keyVaultName) ? keyVaultName : take('${mainIdentifierPrefix}-${uniqueSuffix}', 24)
var vnetName = '${mainIdentifierPrefix}-${uniqueSuffix}-vnet'
var aksClusterName = '${mainIdentifierPrefix}-${uniqueSuffix}-aks'
var postgreSqlServerName = '${mainIdentifierPrefix}-${uniqueSuffix}-psql'
var logAnalyticsWorkspaceName = '${mainIdentifierPrefix}-${uniqueSuffix}-law'
var managedIdentityName = '${mainIdentifierPrefix}-${uniqueSuffix}-identity'
var acrName = !empty(substring(replace('${mainIdentifierPrefix}${uniqueSuffix}acr', '-', ''), 0, 5)) ? take(replace('${mainIdentifierPrefix}${uniqueSuffix}acr', '-', ''), 50) : 'tesacr${uniqueSuffix}'

var commonTags = union(tags, {
  Environment: deploymentEnvironment
  ManagedBy: 'Bicep'
  Project: 'GA4GH-TES'
})

// =============================================================================
// RESOURCE GROUP
// =============================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: finalResourceGroupName
  location: location
  tags: commonTags
}

// =============================================================================
// MODULES
// =============================================================================

// Networking Module
module networking 'modules/networking.bicep' = {
  name: 'networking-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    vnetName: vnetName
    vnetAddressSpace: vnetAddressSpace
    vmSubnetAddressSpace: vmSubnetAddressSpace
    postgreSqlSubnetAddressSpace: postgreSqlSubnetAddressSpace
    batchNodesSubnetAddressSpace: batchNodesSubnetAddressSpace
    tags: commonTags
  }
}

// Managed Identity Module
module identity 'modules/identity.bicep' = {
  name: 'identity-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    managedIdentityName: managedIdentityName
    tags: commonTags
  }
}

// Log Analytics Workspace Module
module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    workspaceName: logAnalyticsWorkspaceName
    tags: commonTags
  }
}

// Application Insights Module
module appInsights 'modules/appInsights.bicep' = {
  name: 'appInsights-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    appInsightsName: finalAppInsightsName
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: commonTags
  }
}

// Storage Account Module
module storage 'modules/storage.bicep' = {
  name: 'storage-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    storageAccountName: finalStorageAccountName
    enablePrivateNetworking: enablePrivateNetworking
    tags: commonTags
  }
}

// PostgreSQL Module
module postgreSql 'modules/postgresql.bicep' = {
  name: 'postgresql-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    serverName: postgreSqlServerName
    administratorLogin: postgreSqlAdministratorLogin
    administratorPassword: !empty(postgreSqlAdministratorPassword) ? postgreSqlAdministratorPassword : uniqueString(resourceGroup.id, postgreSqlServerName, 'admin')
    databaseName: postgreSqlDatabaseName
    skuName: postgreSqlSkuName
    tier: postgreSqlTier
    version: postgreSqlVersion
    storageSizeGB: postgreSqlStorageSize
    subnetId: networking.outputs.postgreSqlSubnetId
    privateDnsZoneName: 'privatelink.postgres.database.azure.com'
    vnetId: networking.outputs.vnetId
    tags: commonTags
  }
}

// Batch Account Module
module batch 'modules/batch.bicep' = {
  name: 'batch-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    batchAccountName: finalBatchAccountName
    storageAccountId: storage.outputs.storageAccountId
    enablePrivateNetworking: enablePrivateNetworking
    tags: commonTags
  }
}

// AKS Cluster Module
module aks 'modules/aks.bicep' = {
  name: 'aks-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    clusterName: aksClusterName
    nodePoolSize: aksPoolSize
    vmSize: aksVmSize
    kubernetesVersion: kubernetesVersion
    subnetId: networking.outputs.vmSubnetId
    serviceCidr: kubernetesServiceCidr
    dnsServiceIP: kubernetesDnsServiceIP
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    managedIdentityId: identity.outputs.identityId
    enablePrivateCluster: enablePrivateNetworking
    aadGroupIds: aadGroupIds
    tags: commonTags
  }
}

// Key Vault Module
module keyVault 'modules/keyVault.bicep' = {
  name: 'keyVault-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    keyVaultName: finalKeyVaultName
    enablePrivateEndpoint: enablePrivateNetworking
    vnetId: networking.outputs.vnetId
    subnetId: networking.outputs.vmSubnetId
    tags: commonTags
  }
}

// Container Registry Module (optional)
module acr 'modules/acr.bicep' = {
  name: 'acr-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    location: location
    acrName: acrName
    tags: commonTags
  }
}

// Role Assignments Module
module roleAssignments 'modules/roleAssignments.bicep' = {
  name: 'roleAssignments-${uniqueSuffix}'
  scope: resourceGroup
  params: {
    managedIdentityPrincipalId: identity.outputs.principalId
    storageAccountId: storage.outputs.storageAccountId
    batchAccountId: batch.outputs.batchAccountId
    appInsightsId: appInsights.outputs.appInsightsId
    acrId: acr.outputs.acrId
    keyVaultName: finalKeyVaultName
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

@description('Resource group name')
output resourceGroupName string = resourceGroup.name

@description('Resource group ID')
output resourceGroupId string = resourceGroup.id

@description('Virtual network ID')
output vnetId string = networking.outputs.vnetId

@description('Virtual network name')
output vnetName string = networking.outputs.vnetName

@description('Storage account ID')
output storageAccountId string = storage.outputs.storageAccountId

@description('Storage account name')
output storageAccountName string = storage.outputs.storageAccountName

@description('Batch account ID')
output batchAccountId string = batch.outputs.batchAccountId

@description('Batch account name')
output batchAccountName string = batch.outputs.batchAccountName

@description('AKS cluster ID')
output aksClusterId string = aks.outputs.clusterId

@description('AKS cluster name')
output aksClusterName string = aks.outputs.clusterName

@description('PostgreSQL server ID')
output postgreSqlServerId string = postgreSql.outputs.serverId

@description('PostgreSQL server name')
output postgreSqlServerName string = postgreSql.outputs.serverName

@description('PostgreSQL database name')
output postgreSqlDatabaseName string = postgreSql.outputs.databaseName

@description('Application Insights connection string')
output appInsightsConnectionString string = appInsights.outputs.connectionString

@description('Managed identity ID')
output managedIdentityId string = identity.outputs.identityId

@description('Managed identity client ID')
output managedIdentityClientId string = identity.outputs.clientId

@description('Key Vault URI')
output keyVaultUri string = keyVault.outputs.vaultUri

@description('Container Registry login server')
output acrLoginServer string = acr.outputs.loginServer
