#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Creates an image definition in Azure Compute Gallery for a team image.

.DESCRIPTION
    This script creates the image definition (metadata) in the Azure Compute Gallery
    before building the actual image. Must be run once per image type.

.PARAMETER ImageType
    The type of team image to create definition for (vscode, dataeng, etc.)

.PARAMETER ResourceGroup
    Resource group containing the Azure Compute Gallery

.PARAMETER GalleryName
    Name of the Azure Compute Gallery

.EXAMPLE
    .\create-image-definition.ps1 -ImageType vscode -ResourceGroup rg-devbox-multi-roles -GalleryName galxvqypooxvqja4
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('vscode', 'dataeng', 'web')]
    [string]$ImageType,

    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$GalleryName
)

$ErrorActionPreference = 'Stop'

# Image configuration mapping
$imageConfigs = @{
    'vscode' = @{
        Name = 'VSCodeDevImage'
        Publisher = 'DevTeams'
        Offer = 'VSCodeDevelopment'
        Sku = 'VSCode-Latest'
        Description = 'VS Code development environment with team customizations'
    }
    'dataeng' = @{
        Name = 'DataEngDevImage'
        Publisher = 'DevTeams'
        Offer = 'DataEngineering'
        Sku = 'DataEng-Latest'
        Description = 'Data engineering environment with Python, SQL, and analytics tools'
    }
    'web' = @{
        Name = 'WebDevImage'
        Publisher = 'DevTeams'
        Offer = 'WebDevelopment'
        Sku = 'Web-Latest'
        Description = 'Web development environment with Node.js and modern frameworks'
    }
}

$config = $imageConfigs[$ImageType]

Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Creating Image Definition: $($config.Name)" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check if already exists
Write-Host "Checking if image definition already exists..." -ForegroundColor Yellow
$existingImage = az sig image-definition show `
    --resource-group $ResourceGroup `
    --gallery-name $GalleryName `
    --gallery-image-definition $config.Name `
    2>$null

if ($existingImage) {
    Write-Host "✓ Image definition '$($config.Name)' already exists" -ForegroundColor Green
    Write-Host ""
    Write-Host "Image details:" -ForegroundColor Cyan
    $imageObj = $existingImage | ConvertFrom-Json
    Write-Host "  Publisher: $($imageObj.identifier.publisher)"
    Write-Host "  Offer: $($imageObj.identifier.offer)"
    Write-Host "  SKU: $($imageObj.identifier.sku)"
    Write-Host "  OS Type: $($imageObj.osType)"
    Write-Host "  OS State: $($imageObj.osState)"
    Write-Host ""
    Write-Host "You can now run the build script to create image versions." -ForegroundColor Green
    exit 0
}

# Create the image definition
Write-Host "Creating new image definition..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Name: $($config.Name)"
Write-Host "  Publisher: $($config.Publisher)"
Write-Host "  Offer: $($config.Offer)"
Write-Host "  SKU: $($config.Sku)"
Write-Host "  Description: $($config.Description)"
Write-Host ""

try {
    az sig image-definition create `
        --resource-group $ResourceGroup `
        --gallery-name $GalleryName `
        --gallery-image-definition $config.Name `
        --publisher $config.Publisher `
        --offer $config.Offer `
        --sku $config.Sku `
        --os-type Windows `
        --os-state Generalized `
        --hyper-v-generation V2 `
        --features SecurityType=TrustedLaunchSupported `
        --description $config.Description

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create image definition"
    }

    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host " ✓ Image Definition Created Successfully" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Run the build script to create image versions:"
    Write-Host "     .\build-image.ps1 -ImageType $ImageType -ImageVersion 1.0.0"
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host " ✗ Failed to Create Image Definition" -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}
