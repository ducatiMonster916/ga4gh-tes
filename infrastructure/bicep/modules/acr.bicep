// =============================================================================
// Azure Container Registry (ACR) Module
// =============================================================================

@description('Azure region for resources')
param location string

@description('Container registry name')
@minLength(5)
@maxLength(50)
param acrName string

@description('Resource tags')
param tags object = {}

@description('ACR SKU')
@allowed(['Basic', 'Standard', 'Premium'])
param sku string = 'Standard'

// =============================================================================
// RESOURCES
// =============================================================================

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 7
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output acrId string = acr.id
output acrName string = acr.name
output loginServer string = acr.properties.loginServer
