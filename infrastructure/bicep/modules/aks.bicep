// =============================================================================
// Azure Kubernetes Service (AKS) Module
// =============================================================================

@description('Azure region for resources')
param location string

@description('AKS cluster name')
param clusterName string

@description('Node pool size (number of nodes)')
@minValue(1)
@maxValue(100)
param nodePoolSize int

@description('VM size for nodes')
param vmSize string

@description('Kubernetes version (leave empty for latest stable)')
param kubernetesVersion string = ''

@description('Subnet ID for AKS')
param subnetId string

@description('Kubernetes service CIDR')
param serviceCidr string

@description('DNS service IP')
param dnsServiceIP string

@description('Log Analytics workspace ID')
param logAnalyticsWorkspaceId string

@description('Managed identity resource ID')
param managedIdentityId string

@description('Enable private cluster')
param enablePrivateCluster bool = false

@description('Azure AD group IDs for cluster admin (comma-separated)')
param aadGroupIds string = ''

@description('Resource tags')
param tags object = {}

// =============================================================================
// VARIABLES
// =============================================================================

var aadGroupIdArray = !empty(aadGroupIds) ? split(aadGroupIds, ',') : []

// =============================================================================
// RESOURCES
// =============================================================================

resource aksCluster 'Microsoft.ContainerService/managedClusters@2025-05-01' = {
  name: clusterName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  properties: {
    kubernetesVersion: !empty(kubernetesVersion) ? kubernetesVersion : null
    dnsPrefix: clusterName
    enableRBAC: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: aadGroupIdArray
    }
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: nodePoolSize
        vmSize: vmSize
        osType: 'Linux'
        osSKU: 'Ubuntu'
        mode: 'System'
        type: 'VirtualMachineScaleSets'
        availabilityZones: []
        enableAutoScaling: false
        vnetSubnetID: subnetId
        maxPods: 110
        enableEncryptionAtHost: false
        enableNodePublicIP: false
      }
    ]
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: serviceCidr
      dnsServiceIP: dnsServiceIP
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
    }
    apiServerAccessProfile: {
      enablePrivateCluster: enablePrivateCluster
    }
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId
        }
      }
      azurePolicy: {
        enabled: true
      }
    }
    oidcIssuerProfile: {
      enabled: true
    }
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }
    autoUpgradeProfile: {
      upgradeChannel: 'stable'
    }
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output clusterId string = aksCluster.id
output clusterName string = aksCluster.name
output clusterFqdn string = aksCluster.properties.fqdn
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL
