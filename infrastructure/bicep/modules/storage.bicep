// =============================================================================
// Storage Account Module
// =============================================================================

@description('Azure region for resources')
param location string

@description('Storage account name (3-24 lowercase alphanumeric characters)')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Enable private networking')
param enablePrivateNetworking bool = false



@description('Resource tags')
param tags object = {}

// =============================================================================
// RESOURCES
// =============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: enablePrivateNetworking ? {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    } : {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2025-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// Default Containers
var defaultContainers = [
  'tes-internal'
  'inputs'
  'outputs'
  'configuration'
]

resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-01-01' = [for container in defaultContainers: {
  parent: blobService
  name: container
  properties: {
    publicAccess: 'None'
  }
}]

// =============================================================================
// OUTPUTS
// =============================================================================

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
