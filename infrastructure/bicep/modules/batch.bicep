// =============================================================================
// Azure Batch Account Module
// =============================================================================

@description('Azure region for resources')
param location string

@description('Batch account name')
@minLength(3)
@maxLength(24)
param batchAccountName string

@description('Storage account resource ID for auto-storage')
param storageAccountId string

@description('Enable private networking')
param enablePrivateNetworking bool = false

@description('Resource tags')
param tags object = {}

// =============================================================================
// RESOURCES
// =============================================================================

resource batchAccount 'Microsoft.Batch/batchAccounts@2024-07-01' = {
  name: batchAccountName
  location: location
  tags: tags
  properties: {
    autoStorage: enablePrivateNetworking ? {
      storageAccountId: storageAccountId
    } : null
    publicNetworkAccess: enablePrivateNetworking ? 'Disabled' : 'Enabled'
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output batchAccountId string = batchAccount.id
output batchAccountName string = batchAccount.name
output batchAccountEndpoint string = batchAccount.properties.accountEndpoint
