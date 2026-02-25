// =============================================================================
// Managed Identity Module - User-Assigned Managed Identity
// =============================================================================

@description('Azure region for resources')
param location string

@description('Managed identity name')
param managedIdentityName string

@description('Resource tags')
param tags object = {}

// =============================================================================
// RESOURCES
// =============================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

// =============================================================================
// OUTPUTS
// =============================================================================

output identityId string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output clientId string = managedIdentity.properties.clientId
