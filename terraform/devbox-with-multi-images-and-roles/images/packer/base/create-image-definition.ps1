#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates the SecurityBaselineImage definition in Azure Compute Gallery

.DESCRIPTION
    This script creates the image definition for the SecurityBaselineImage.
    This must be run ONCE before building the baseline image with Packer.
    
.PARAMETER VarFile
    Path to Packer variables file (default: security-baseline.pkrvars.hcl)

.EXAMPLE
    .\create-image-definition.ps1
    
    Creates the image definition using default variables file

.EXAMPLE
    .\create-image-definition.ps1 -VarFile custom.pkrvars.hcl
    
    Creates the image definition using custom variables file
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$VarFile = "security-baseline.pkrvars.hcl"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

function Get-PackerVariable {
    param(
        [string]$FilePath,
        [string]$VariableName
    )
    
    $content = Get-Content $FilePath -Raw
    if ($content -match "$VariableName\s*=\s*`"([^`"]+)`"") {
        return $Matches[1]
    }
    throw "Variable '$VariableName' not found in $FilePath"
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host " Creating SecurityBaselineImage Definition" -ForegroundColor Cyan
Write-Host "=============================================================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$varFilePath = Join-Path $scriptDir $VarFile

# Check if variables file exists
if (-not (Test-Path $varFilePath)) {
    Write-Host "ERROR: Variables file not found: $varFilePath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create the file by copying the example:" -ForegroundColor Yellow
    Write-Host "  cp security-baseline.pkrvars.hcl.example security-baseline.pkrvars.hcl" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "Reading configuration from: $varFilePath" -ForegroundColor Gray
Write-Host ""

# Parse variables from HCL file
try {
    $resourceGroup = Get-PackerVariable -FilePath $varFilePath -VariableName "resource_group_name"
    $galleryName = Get-PackerVariable -FilePath $varFilePath -VariableName "gallery_name"
    $location = Get-PackerVariable -FilePath $varFilePath -VariableName "location"
    
    Write-Host "Configuration:" -ForegroundColor White
    Write-Host "  Resource Group: $resourceGroup" -ForegroundColor Gray
    Write-Host "  Gallery Name: $galleryName" -ForegroundColor Gray
    Write-Host "  Location: $location" -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "ERROR: Failed to parse variables file: $_" -ForegroundColor Red
    exit 1
}

# Check if already exists
Write-Host "Checking if image definition already exists..." -ForegroundColor Gray
$existingImage = az sig image-definition show `
    --resource-group $resourceGroup `
    --gallery-name $galleryName `
    --gallery-image-definition SecurityBaselineImage `
    2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Image definition 'SecurityBaselineImage' already exists" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now build the baseline image:" -ForegroundColor White
    Write-Host "  .\build-baseline-image.ps1 -ImageVersion `"1.0.0`"" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

# Create image definition
Write-Host "Creating image definition 'SecurityBaselineImage'..." -ForegroundColor White
Write-Host ""

az sig image-definition create `
    --resource-group $resourceGroup `
    --gallery-name $galleryName `
    --gallery-image-definition SecurityBaselineImage `
    --publisher MicrosoftCorporation `
    --offer DevBox `
    --sku SecurityBaseline `
    --os-type Windows `
    --os-state Generalized `
    --hyper-v-generation V2 `
    --location $location `
    --description "Golden Security Baseline Image - Mandatory foundation for all DevBox images. Contains security hardening, compliance tools, and Azure AD join configuration." `
    --features "SecurityType=TrustedLaunch IsHibernateSupported=true" `
    --tags "ManagedBy=Operations" "Purpose=SecurityBaseline" "Type=GoldenImage"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Failed to create image definition" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host " Image Definition Created Successfully!" -ForegroundColor Green
Write-Host "=============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Build the baseline image:" -ForegroundColor Gray
Write-Host "     .\build-baseline-image.ps1 -ImageVersion `"1.0.0`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Development teams can then reference this in their templates:" -ForegroundColor Gray
Write-Host "     shared_image_gallery {" -ForegroundColor Cyan
Write-Host "       gallery_name  = `"$galleryName`"" -ForegroundColor Cyan
Write-Host "       image_name    = `"SecurityBaselineImage`"" -ForegroundColor Cyan
Write-Host "       image_version = `"1.0.0`"" -ForegroundColor Cyan
Write-Host "     }" -ForegroundColor Cyan
Write-Host ""
