// =============================================================================
// PostgreSQL Flexible Server Module
// =============================================================================

@description('Azure region for resources')
param location string

@description('PostgreSQL server name')
param serverName string

@description('Administrator username')
param administratorLogin string

@description('Administrator password')
@secure()
param administratorPassword string

@description('Database name')
param databaseName string

@description('PostgreSQL SKU name')
param skuName string

@description('PostgreSQL tier')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param tier string

@description('PostgreSQL version')
@allowed(['11', '12', '13', '14', '15', '16'])
param version string

@description('Storage size in GB')
param storageSizeGB int

@description('Subnet ID for PostgreSQL delegation')
param subnetId string

@description('Private DNS zone name')
param privateDnsZoneName string

@description('Virtual network ID')
param vnetId string

@description('Resource tags')
param tags object = {}

// =============================================================================
// RESOURCES
// =============================================================================

// Private DNS Zone for PostgreSQL
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
  tags: tags
}

// Link DNS Zone to VNet
resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

// PostgreSQL Flexible Server
resource postgreSqlServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-03-01-preview' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: tier
  }
  properties: {
    version: version
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    network: {
      delegatedSubnetResourceId: subnetId
      privateDnsZoneArmResourceId: privateDnsZone.id
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
  dependsOn: [
    dnsZoneLink
  ]
}

// PostgreSQL Database
resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-03-01-preview' = {
  parent: postgreSqlServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL Firewall Rule - Allow Azure Services
resource firewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-03-01-preview' = {
  parent: postgreSqlServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output serverId string = postgreSqlServer.id
output serverName string = postgreSqlServer.name
output serverFqdn string = postgreSqlServer.properties.fullyQualifiedDomainName
output databaseName string = database.name
output privateDnsZoneId string = privateDnsZone.id
