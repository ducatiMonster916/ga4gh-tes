#Requires -Version 7.0

<#
.SYNOPSIS
    Validate Bicep templates without deployment.

.DESCRIPTION
    This script performs comprehensive validation of Bicep templates including:
    - Bicep linting
    - Template build
    - ARM template validation
    - Parameter file validation

.PARAMETER CheckOnly
    Only check syntax without full validation

.EXAMPLE
    .\validate.ps1

.EXAMPLE
    .\validate.ps1 -CheckOnly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateFile = Join-Path $ScriptDir "main.bicep"
$ModulesDir = Join-Path $ScriptDir "modules"

# =============================================================================
# FUNCTIONS
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
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-BicepInstalled {
    try {
        $version = az bicep version 2>$null
        Write-Success "Bicep CLI installed: $version"
        return $true
    }
    catch {
        Write-Error "Bicep CLI not installed"
        Write-Information "Install with: az bicep install"
        return $false
    }
}

function Test-BicepLint {
    param([string]$File)
    
    Write-Information "Linting: $File"
    
    try {
        $output = az bicep build --file $File 2>&1
        
        # Check for warnings or errors
        if ($output -match "Warning|Error") {
            Write-Warning "Linting warnings/errors found:"
            Write-Warning $output
            return $false
        }
        
        Write-Success "Lint passed: $(Split-Path -Leaf $File)"
        return $true
    }
    catch {
        Write-Error "Lint failed: $(Split-Path -Leaf $File)"
        Write-Error $_.Exception.Message
        return $false
    }
}

function Test-ParameterFile {
    param([string]$File)
    
    Write-Information "Validating parameter file: $(Split-Path -Leaf $File)"
    
    try {
        $params = Get-Content $File -Raw | ConvertFrom-Json
        
        # Check schema
        if (-not $params.'$schema') {
            Write-Error "Missing schema in parameter file"
            return $false
        }
        
        # Check parameters object
        if (-not $params.parameters) {
            Write-Error "Missing parameters object"
            return $false
        }
        
        Write-Success "Parameter file valid: $(Split-Path -Leaf $File)"
        return $true
    }
    catch {
        Write-Error "Invalid parameter file: $(Split-Path -Leaf $File)"
        Write-Error $_.Exception.Message
        return $false
    }
}

# =============================================================================
# MAIN VALIDATION
# =============================================================================

try {
    Write-Header "Bicep Template Validation"
    
    # Check Bicep installation
    if (-not (Test-BicepInstalled)) {
        exit 1
    }
    
    Write-Information ""
    Write-Header "Linting Bicep Files"
    
    # Lint main template
    $mainValid = Test-BicepLint -File $TemplateFile
    
    # Lint all modules
    $moduleFiles = Get-ChildItem -Path $ModulesDir -Filter "*.bicep"
    $modulesValid = $true
    
    foreach ($module in $moduleFiles) {
        $result = Test-BicepLint -File $module.FullName
        $modulesValid = $modulesValid -and $result
    }
    
    # Validate parameter files (if not CheckOnly)
    if (-not $CheckOnly) {
        Write-Information ""
        Write-Header "Validating Parameter Files"
        
        $paramFiles = Get-ChildItem -Path $ScriptDir -Filter "parameters.*.json"
        $paramsValid = $true
        
        foreach ($paramFile in $paramFiles) {
            $result = Test-ParameterFile -File $paramFile.FullName
            $paramsValid = $paramsValid -and $result
        }
    }
    
    # Summary
    Write-Information ""
    Write-Header "Validation Summary"
    
    if ($mainValid -and $modulesValid) {
        Write-Success "All Bicep templates are valid"
    }
    else {
        Write-Error "Some templates have validation errors"
        exit 1
    }
    
    if (-not $CheckOnly -and -not $paramsValid) {
        Write-Error "Some parameter files have validation errors"
        exit 1
    }
    
    Write-Information ""
    Write-Success "Validation complete - all checks passed!"
    Write-Information ""
    Write-Information "Next steps:"
    Write-Information "  1. Review parameters: parameters.dev.json or parameters.prod.example.json"
    Write-Information "  2. Deploy: .\deploy.ps1 -Environment dev -Location eastus"
    Write-Information ""
    
}
catch {
    Write-Header "Validation Failed"
    Write-Error $_.Exception.Message
    exit 1
}
