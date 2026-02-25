// =============================================================================
// Role Assignments Module
// =============================================================================
// Assigns necessary RBAC roles to the managed identity for accessing
// Azure resources (Storage, Batch, Application Insights, ACR, Key Vault)

@description('Managed identity principal ID')
param managedIdentityPrincipalId string

@description('Storage account resource ID')
param storageAccountId string

@description('Batch account resource ID')
param batchAccountId string

@description('Application Insights resource ID')
param appInsightsId string

@description('Container Registry resource ID')
param acrId string

@description('Key Vault name')
param keyVaultName string

// =============================================================================
// BUILT-IN ROLE DEFINITION IDS
// =============================================================================

// Storage Account Roles
var storageBlobDataContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
var storageBlobDataOwnerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')

// Batch Account Roles
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

// ACR Roles
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

// Key Vault Roles
var keyVaultSecretsOfficerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')

// =============================================================================
// ROLE ASSIGNMENTS
// =============================================================================

// Storage Blob Data Contributor - for storage account access
resource storageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, managedIdentityPrincipalId, storageBlobDataContributorRoleId)
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Owner - for full storage operations
resource storageBlobDataOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, managedIdentityPrincipalId, storageBlobDataOwnerRoleId)
  properties: {
    roleDefinitionId: storageBlobDataOwnerRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Contributor - for Batch account management
resource batchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(batchAccountId, managedIdentityPrincipalId, contributorRoleId)
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Contributor - for Application Insights access
resource appInsightsContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsightsId, managedIdentityPrincipalId, contributorRoleId)
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// AcrPull - for pulling images from ACR
resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, managedIdentityPrincipalId, acrPullRoleId)
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Key Vault Secrets Officer - for Key Vault secret management  
resource keyVaultSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultName, managedIdentityPrincipalId, keyVaultSecretsOfficerRoleId)
  properties: {
    roleDefinitionId: keyVaultSecretsOfficerRoleId
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output assignmentIds array = [
  storageBlobDataContributor.id
  storageBlobDataOwner.id
  batchContributor.id
  appInsightsContributor.id
  acrPull.id
  keyVaultSecretsOfficer.id
]
