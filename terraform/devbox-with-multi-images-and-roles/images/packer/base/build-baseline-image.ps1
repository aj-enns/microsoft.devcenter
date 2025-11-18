#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds the Golden Security Baseline Image for DevBox

.DESCRIPTION
    This script builds the security baseline image that ALL team-specific images
    must use as their foundation. This image contains mandatory security configurations,
    compliance tools, and Azure AD join readiness.
    
    OWNERSHIP: Operations Team Only
    PROTECTED BY: CODEOWNERS - Requires @operations-team approval
    
    The resulting "SecurityBaselineImage" in the Azure Compute Gallery will be used
    as the source for all team-specific image builds.

.PARAMETER ImageVersion
    Semantic version for the baseline image (e.g., "1.0.0", "1.1.0", "2.0.0")
    Required parameter - no default

.PARAMETER ValidateOnly
    Only validates the Packer template without building the image

.PARAMETER Force
    Skip confirmation prompts (use in CI/CD pipelines)

.PARAMETER VarFile
    Path to Packer variables file (default: security-baseline.pkrvars.hcl)

.EXAMPLE
    .\build-baseline-image.ps1 -ImageVersion "1.0.0"
    
    Builds version 1.0.0 of the security baseline image

.EXAMPLE
    .\build-baseline-image.ps1 -ImageVersion "1.1.0" -ValidateOnly
    
    Validates the Packer template without building

.EXAMPLE
    .\build-baseline-image.ps1 -ImageVersion "1.0.0" -Force
    
    Builds without confirmation prompts (for automation)

.NOTES
    Prerequisites:
    - Azure CLI installed and authenticated (az login)
    - Packer 1.9.0+ installed
    - Terraform infrastructure deployed (Gallery must exist)
    - security-baseline.pkrvars.hcl file with Azure resource details
    
    Build Time: Approximately 45-60 minutes
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$ImageVersion,
    
    [Parameter(Mandatory=$false)]
    [switch]$ValidateOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
    [Parameter(Mandatory=$false)]
    [string]$VarFile = "security-baseline.pkrvars.hcl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# CONSTANTS
# =============================================================================

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PACKER_TEMPLATE = Join-Path $SCRIPT_DIR "security-baseline.pkr.hcl"
$VAR_FILE_PATH = Join-Path $SCRIPT_DIR $VarFile
$MANIFEST_FILE = Join-Path $SCRIPT_DIR "manifest-security-baseline.json"

# =============================================================================
# FUNCTIONS
# =============================================================================

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host " $Message" -ForegroundColor Cyan
    Write-Host "=============================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Blue
}

function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    
    $allGood = $true
    
    # Check Packer
    Write-Host "Checking Packer installation..."
    try {
        $packerVersion = packer version
        if ($packerVersion -match 'Packer v(\d+\.\d+\.\d+)') {
            $version = [version]$matches[1]
            if ($version -ge [version]"1.9.0") {
                Write-Success "Packer $($matches[1]) installed"
            } else {
                Write-Error "Packer version $($matches[1]) is too old. Require 1.9.0+"
                $allGood = $false
            }
        }
    } catch {
        Write-Error "Packer not found. Install from: https://www.packer.io/downloads"
        $allGood = $false
    }
    
    # Check Azure CLI
    Write-Host "Checking Azure CLI installation..."
    try {
        $azVersion = az version --query '\"azure-cli\"' -o tsv
        Write-Success "Azure CLI $azVersion installed"
    } catch {
        Write-Error "Azure CLI not found. Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        $allGood = $false
    }
    
    # Check Azure authentication
    Write-Host "Checking Azure authentication..."
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Success "Authenticated as: $($account.user.name)"
            Write-Info "  Subscription: $($account.name) ($($account.id))"
        } else {
            Write-Error "Not authenticated to Azure. Run: az login"
            $allGood = $false
        }
    } catch {
        Write-Error "Not authenticated to Azure. Run: az login"
        $allGood = $false
    }
    
    # Check template file
    Write-Host "Checking Packer template..."
    if (Test-Path $PACKER_TEMPLATE) {
        Write-Success "Template found: $PACKER_TEMPLATE"
    } else {
        Write-Error "Template not found: $PACKER_TEMPLATE"
        $allGood = $false
    }
    
    # Check variables file
    Write-Host "Checking variables file..."
    if (Test-Path $VAR_FILE_PATH) {
        Write-Success "Variables file found: $VAR_FILE_PATH"
    } else {
        Write-Error "Variables file not found: $VAR_FILE_PATH"
        Write-Info "  Copy security-baseline.pkrvars.hcl.example to $VarFile"
        Write-Info "  Then edit with your Azure resource details"
        $allGood = $false
    }
    
    Write-Host ""
    return $allGood
}

function Initialize-Packer {
    Write-Header "Initializing Packer"
    
    Write-Host "Running: packer init $PACKER_TEMPLATE"
    packer init $PACKER_TEMPLATE
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Packer initialized successfully"
    } else {
        Write-Error "Packer initialization failed"
        throw "Packer init failed with exit code $LASTEXITCODE"
    }
}

function Test-PackerTemplate {
    Write-Header "Validating Packer Template"
    
    Write-Host "Running: packer validate -var-file=`"$VAR_FILE_PATH`" -var `"image_version=$ImageVersion`" $PACKER_TEMPLATE"
    Write-Host ""
    
    packer validate -var-file="$VAR_FILE_PATH" -var "image_version=$ImageVersion" $PACKER_TEMPLATE
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Template validation passed"
        return $true
    } else {
        Write-Error "Template validation failed"
        return $false
    }
}

function Build-BaselineImage {
    Write-Header "Building Security Baseline Image v$ImageVersion"
    
    Write-Warning "This build will take approximately 45-60 minutes"
    Write-Info "Image Name: SecurityBaselineImage"
    Write-Info "Version: $ImageVersion"
    Write-Info "Template: $PACKER_TEMPLATE"
    Write-Info "Variables: $VAR_FILE_PATH"
    Write-Host ""
    
    if (-not $Force) {
        $confirmation = Read-Host "Continue with build? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Warning "Build cancelled by user"
            return $false
        }
    }
    
    Write-Host ""
    Write-Host "Starting Packer build at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""
    
    $startTime = Get-Date
    
    # Run Packer build
    packer build `
        -var-file="$VAR_FILE_PATH" `
        -var "image_version=$ImageVersion" `
        -force `
        $PACKER_TEMPLATE
    
    $buildExitCode = $LASTEXITCODE
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host ""
    Write-Host "Build finished at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Duration: $($duration.ToString('hh\:mm\:ss'))"
    Write-Host ""
    
    if ($buildExitCode -eq 0) {
        Write-Success "Build completed successfully!"
        return $true
    } else {
        Write-Error "Build failed with exit code $buildExitCode"
        return $false
    }
}

function Show-BuildResults {
    Write-Header "Build Results"
    
    if (Test-Path $MANIFEST_FILE) {
        Write-Success "Manifest file created: $MANIFEST_FILE"
        Write-Host ""
        
        $manifest = Get-Content $MANIFEST_FILE | ConvertFrom-Json
        Write-Info "Image Details:"
        Write-Host "  Name: $($manifest.custom_data.image_name)"
        Write-Host "  Version: $($manifest.custom_data.image_version)"
        Write-Host "  Build Time: $($manifest.custom_data.build_time)"
        Write-Host "  Description: $($manifest.custom_data.description)"
        Write-Host ""
    }
    
    Write-Success "Security Baseline Image is now available in Azure Compute Gallery"
    Write-Host ""
    Write-Info "Next Steps:"
    Write-Host "  1. Development teams can now reference this image in their Packer templates"
    Write-Host "  2. Update team templates to use: SecurityBaselineImage-$ImageVersion"
    Write-Host "  3. Rebuild team-specific images to include the latest baseline"
    Write-Host ""
    Write-Info "Example team template configuration:"
    Write-Host "  shared_image_gallery {"
    Write-Host "    gallery_name  = var.gallery_name"
    Write-Host "    image_name    = `"SecurityBaselineImage`""
    Write-Host "    image_version = `"$ImageVersion`""
    Write-Host "  }"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

try {
    Write-Header "Golden Security Baseline Image Builder"
    Write-Host "Image Version: $ImageVersion"
    Write-Host "Mode: $(if ($ValidateOnly) { 'Validate Only' } else { 'Build' })"
    Write-Host ""
    
    # Step 1: Check prerequisites
    if (-not (Test-Prerequisites)) {
        throw "Prerequisites check failed. Please resolve the issues above."
    }
    
    # Step 2: Initialize Packer
    Initialize-Packer
    
    # Step 3: Validate template
    if (-not (Test-PackerTemplate)) {
        throw "Template validation failed"
    }
    
    # Stop here if validate-only mode
    if ($ValidateOnly) {
        Write-Success "Validation completed successfully!"
        Write-Info "Use without -ValidateOnly to build the image"
        exit 0
    }
    
    # Step 4: Build image
    if (-not (Build-BaselineImage)) {
        throw "Image build failed"
    }
    
    # Step 5: Show results
    Show-BuildResults
    
    Write-Header "Build Process Complete"
    Write-Success "Golden Security Baseline Image v$ImageVersion is ready!"
    exit 0
    
} catch {
    Write-Host ""
    Write-Error "An error occurred: $_"
    Write-Host ""
    exit 1
}
