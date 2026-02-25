// =============================================================================
// Networking Module - Virtual Network and Subnets
// =============================================================================

@description('Azure region for resources')
param location string

@description('Virtual network name')
param vnetName string

@description('Virtual network address space')
param vnetAddressSpace string

@description('VM/AKS subnet address space')
param vmSubnetAddressSpace string

@description('PostgreSQL subnet address space')
param postgreSqlSubnetAddressSpace string

@description('Batch nodes subnet address space')
param batchNodesSubnetAddressSpace string

@description('Resource tags')
param tags object = {}

// =============================================================================
// RESOURCES
// =============================================================================

// Network Security Group for AKS/VM subnet
resource aksNsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: '${vnetName}-aks-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowHTTPS'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowHTTP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 110
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Default Network Security Group
resource defaultNsg 'Microsoft.Network/networkSecurityGroups@2024-07-01' = {
  name: '${vnetName}-default-nsg'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-07-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'vmsubnet'
        properties: {
          addressPrefix: vmSubnetAddressSpace
          networkSecurityGroup: {
            id: aksNsg.id
          }
          serviceEndpoints: []
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'sqlsubnet'
        properties: {
          addressPrefix: postgreSqlSubnetAddressSpace
          networkSecurityGroup: {
            id: defaultNsg.id
          }
          serviceEndpoints: []
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL.flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'batchsubnet'
        properties: {
          addressPrefix: batchNodesSubnetAddressSpace
          networkSecurityGroup: {
            id: defaultNsg.id
          }
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.KeyVault'
            }
          ]
          delegations: []
          privateEndpointNetworkPolicies: 'Enabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output vnetId string = vnet.id
output vnetName string = vnet.name
output vmSubnetId string = vnet.properties.subnets[0].id
output postgreSqlSubnetId string = vnet.properties.subnets[1].id
output batchSubnetId string = vnet.properties.subnets[2].id
output aksNsgId string = aksNsg.id
output defaultNsgId string = defaultNsg.id
