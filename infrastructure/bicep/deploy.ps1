#Requires -Version 7.0

<#
.SYNOPSIS
    Deploy GA4GH TES infrastructure using Bicep templates.

.DESCRIPTION
    This script validates and deploys the TES infrastructure to Azure using Bicep.
    It supports multiple environments (dev, staging, prod) and provides validation,
    what-if analysis, and deployment capabilities.

.PARAMETER Environment
    Target environment: dev, staging, or prod

.PARAMETER Location
    Azure region for deployment (e.g., eastus, westus2)

.PARAMETER ParameterFile
    Path to the parameter file (optional, defaults to parameters.{Environment}.json)

.PARAMETER WhatIf
    Run what-if analysis without deploying

.PARAMETER Validate
    Validate the template without deploying

.PARAMETER SkipValidation
    Skip validation and deploy immediately

.PARAMETER ResourceGroupPrefix
    Prefix for the resource group and resources

.EXAMPLE
    .\deploy.ps1 -Environment dev -Location eastus
    
.EXAMPLE
    .\deploy.ps1 -Environment prod -Location eastus -WhatIf

.EXAMPLE
    .\deploy.ps1 -Environment prod -ParameterFile custom-params.json -Validate

#>

[CmdletBinding(DefaultParameterSetName = 'Deploy')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = "",

    [Parameter(ParameterSetName = 'WhatIf')]
    [switch]$WhatIf,

    [Parameter(ParameterSetName = 'Validate')]
    [switch]$Validate,

    [Parameter(ParameterSetName = 'Deploy')]
    [switch]$SkipValidation,

    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupPrefix = "tes"
)

# =============================================================================
# CONFIGURATION
# =============================================================================

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateFile = Join-Path $ScriptDir "main.bicep"
$DeploymentName = "tes-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Determine parameter file
if ([string]::IsNullOrEmpty($ParameterFile)) {
    $ParameterFile = Join-Path $ScriptDir "parameters.$Environment.json"
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Write-Header {
    param([string]$Message)
    Write-Information ""
    Write-Information "================================================================================"
    Write-Information " $Message"
    Write-Information "================================================================================"
    Write-Information ""
}

function Write-Success {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    # Check Azure CLI
    try {
        $azVersion = az version --query '"azure-cli"' -o tsv 2>$null
        Write-Information "✓ Azure CLI version: $azVersion"
    }
    catch {
        throw "Azure CLI is not installed. Install from: https://aka.ms/azure-cli"
    }

    # Check Bicep
    try {
        $bicepVersion = az bicep version 2>$null
        Write-Information "✓ Bicep CLI: $bicepVersion"
    }
    catch {
        throw "Bicep CLI is not installed. Run: az bicep install"
    }

    # Check authentication
    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not authenticated to Azure. Run: az login"
    }
    
    Write-Information "✓ Authenticated as: $($account.user.name)"
    Write-Information "✓ Subscription: $($account.name) ($($account.id))"

    # Check template file
    if (-not (Test-Path $TemplateFile)) {
        throw "Template file not found: $TemplateFile"
    }
    Write-Information "✓ Template file: $TemplateFile"

    # Check parameter file
    if (-not (Test-Path $ParameterFile)) {
        throw "Parameter file not found: $ParameterFile"
    }
    Write-Information "✓ Parameter file: $ParameterFile"
}

function Invoke-BicepBuild {
    Write-Header "Building Bicep Template"
    
    try {
        az bicep build --file $TemplateFile
        Write-Success "✓ Bicep build successful"
    }
    catch {
        Write-Error "✗ Bicep build failed"
        throw
    }
}

function Invoke-TemplateValidation {
    Write-Header "Validating Deployment Template"
    
    try {
        $validation = az deployment sub validate `
            --location $Location `
            --template-file $TemplateFile `
            --parameters "@$ParameterFile" `
            2>&1 | ConvertFrom-Json

        if ($validation.error) {
            Write-Error "✗ Validation failed"
            Write-Error $validation.error.message
            throw "Validation errors found"
        }

        Write-Success "✓ Template validation successful"
        return $validation
    }
    catch {
        Write-Error "✗ Template validation failed"
        throw
    }
}

function Invoke-WhatIfAnalysis {
    Write-Header "Running What-If Analysis"
    
    Write-Information "Analyzing changes that will be made..."
    Write-Information ""
    
    try {
        az deployment sub what-if `
            --location $Location `
            --template-file $TemplateFile `
            --parameters "@$ParameterFile"
        
        Write-Information ""
        Write-Success "✓ What-If analysis complete"
    }
    catch {
        Write-Error "✗ What-If analysis failed"
        throw
    }
}

function Invoke-Deployment {
    Write-Header "Deploying Infrastructure"
    
    Write-Information "Deployment Name: $DeploymentName"
    Write-Information "Location: $Location"
    Write-Information "Environment: $Environment"
    Write-Information ""
    
    # Confirm deployment
    $confirm = Read-Host "Do you want to proceed with deployment? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Warning "Deployment cancelled by user"
        exit 0
    }

    Write-Information ""
    Write-Information "Starting deployment... (this may take 15-25 minutes)"
    Write-Information ""

    try {
        $result = az deployment sub create `
            --name $DeploymentName `
            --location $Location `
            --template-file $TemplateFile `
            --parameters "@$ParameterFile" `
            --output json | ConvertFrom-Json

        if ($result.properties.provisioningState -eq "Succeeded") {
            Write-Success "✓ Deployment completed successfully"
            return $result
        }
        else {
            Write-Error "✗ Deployment failed with state: $($result.properties.provisioningState)"
            throw "Deployment did not succeed"
        }
    }
    catch {
        Write-Error "✗ Deployment failed"
        Write-Error $_.Exception.Message
        throw
    }
}

function Write-DeploymentOutputs {
    param([object]$Deployment)
    
    Write-Header "Deployment Outputs"
    
    $outputs = $Deployment.properties.outputs
    
    Write-Information "Resource Group:"
    Write-Information "  Name: $($outputs.resourceGroupName.value)"
    Write-Information "  ID: $($outputs.resourceGroupId.value)"
    Write-Information ""
    
    Write-Information "Networking:"
    Write-Information "  VNet Name: $($outputs.vnetName.value)"
    Write-Information "  VNet ID: $($outputs.vnetId.value)"
    Write-Information ""
    
    Write-Information "Storage:"
    Write-Information "  Storage Account: $($outputs.storageAccountName.value)"
    Write-Information ""
    
    Write-Information "Compute:"
    Write-Information "  AKS Cluster: $($outputs.aksClusterName.value)"
    Write-Information "  Batch Account: $($outputs.batchAccountName.value)"
    Write-Information ""
    
    Write-Information "Database:"
    Write-Information "  PostgreSQL Server: $($outputs.postgreSqlServerName.value)"
    Write-Information "  Database: $($outputs.postgreSqlDatabaseName.value)"
    Write-Information ""
    
    Write-Information "Security:"
    Write-Information "  Key Vault URI: $($outputs.keyVaultUri.value)"
    Write-Information "  Managed Identity ID: $($outputs.managedIdentityClientId.value)"
    Write-Information ""
    
    Write-Information "Monitoring:"
    Write-Information "  App Insights Connection String: [SENSITIVE - Check Azure Portal]"
    Write-Information ""
    
    Write-Information "Container Registry:"
    Write-Information "  ACR Login Server: $($outputs.acrLoginServer.value)"
    Write-Information ""
    
    Write-Success "Deployment outputs saved above"
}

function Write-NextSteps {
    param([object]$Outputs)
    
    Write-Header "Next Steps"
    
    $rgName = $Outputs.resourceGroupName.value
    $aksName = $Outputs.aksClusterName.value
    $acrName = $Outputs.acrLoginServer.value.Split('.')[0]
    
    Write-Information "1. Configure kubectl access to AKS:"
    Write-Host "   az aks get-credentials --resource-group $rgName --name $aksName" -ForegroundColor Cyan
    Write-Information ""
    
    Write-Information "2. Login to Azure Container Registry:"
    Write-Host "   az acr login --name $acrName" -ForegroundColor Cyan
    Write-Information ""
    
    Write-Information "3. Build and push TES container image:"
    Write-Host "   docker build -t $acrName.azurecr.io/tes:latest -f ../src/Dockerfile-Tes ." -ForegroundColor Cyan
    Write-Host "   docker push $acrName.azurecr.io/tes:latest" -ForegroundColor Cyan
    Write-Information ""
    
    Write-Information "4. Deploy TES to AKS (if you have Kubernetes manifests):"
    Write-Host "   kubectl apply -f ../kubernetes/tes-deployment.yaml" -ForegroundColor Cyan
    Write-Information ""
    
    Write-Information "5. Verify deployment:"
    Write-Host "   kubectl get pods" -ForegroundColor Cyan
    Write-Host "   kubectl get services" -ForegroundColor Cyan
    Write-Information ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-Header "GA4GH TES Infrastructure Deployment"
    Write-Information "Environment: $Environment"
    Write-Information "Location: $Location"
    Write-Information "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Check prerequisites
    Test-Prerequisites
    
    # Build Bicep template
    Invoke-BicepBuild
    
    # Handle execution mode
    switch ($PSCmdlet.ParameterSetName) {
        'Validate' {
            Invoke-TemplateValidation
            Write-Success "Validation complete - no deployment performed"
        }
        'WhatIf' {
            Invoke-WhatIfAnalysis
            Write-Success "What-If analysis complete - no deployment performed"
        }
        'Deploy' {
            if (-not $SkipValidation) {
                Invoke-TemplateValidation
            }
            
            $deployment = Invoke-Deployment
            Write-DeploymentOutputs -Deployment $deployment
            Write-NextSteps -Outputs $deployment.properties.outputs
            
            Write-Header "Deployment Complete"
            Write-Success "Infrastructure deployed successfully!"
        }
    }
}
catch {
    Write-Header "Deployment Failed"
    Write-Error "An error occurred during deployment:"
    Write-Error $_.Exception.Message
    Write-Error ""
    Write-Error "Stack Trace:"
    Write-Error $_.ScriptStackTrace
    exit 1
}
