#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Verifies that custom images from the Compute Gallery are synced to DevCenter.

.DESCRIPTION
    After attaching a Compute Gallery to a DevCenter, it can take several minutes
    to a few hours for custom images to be indexed and available. This script
    checks the sync status.

.EXAMPLE
    .\00-verify-gallery-sync.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " DevCenter Gallery Sync Verification" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Read Terraform outputs
Write-Host "Step 1: Reading infrastructure configuration..." -ForegroundColor Yellow

# Change to infrastructure directory to read Terraform state
$originalDir = Get-Location
Set-Location (Join-Path $PSScriptRoot "..")

try {
    $outputs = terraform output -json | ConvertFrom-Json
    
    $devCenterName = $outputs.dev_center_name.value
    $resourceGroup = $outputs.resource_group_name.value
    $galleryName = $outputs.gallery_name.value
} finally {
    Set-Location $originalDir
}

Write-Host "  ✓ DevCenter: $devCenterName" -ForegroundColor Green
Write-Host "  ✓ Resource Group: $resourceGroup" -ForegroundColor Green
Write-Host "  ✓ Gallery: $galleryName" -ForegroundColor Green
Write-Host ""

# Check gallery attachment
Write-Host "Step 2: Checking gallery attachment..." -ForegroundColor Yellow
$galleryAttachment = az devcenter admin gallery show `
    --dev-center-name $devCenterName `
    --resource-group $resourceGroup `
    --gallery-name default `
    --query "{State:provisioningState}" -o json 2>&1

if ($LASTEXITCODE -eq 0) {
    $galleryInfo = $galleryAttachment | ConvertFrom-Json
    Write-Host "  ✓ Gallery attached (State: $($galleryInfo.State))" -ForegroundColor Green
} else {
    Write-Host "  ✗ Gallery not attached to DevCenter" -ForegroundColor Red
    Write-Host "    Run: terraform apply" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# List images in Compute Gallery
Write-Host "Step 3: Images in Compute Gallery..." -ForegroundColor Yellow
$computeImages = az sig image-definition list `
    --gallery-name $galleryName `
    --resource-group $resourceGroup `
    --query "[].name" -o json | ConvertFrom-Json

if ($computeImages.Count -eq 0) {
    Write-Host "  ⚠️  No images found in Compute Gallery" -ForegroundColor Yellow
    Write-Host "    Development teams need to build images first" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

Write-Host "  Found $($computeImages.Count) image definition(s):" -ForegroundColor Gray
foreach ($img in $computeImages) {
    # Check if versions exist
    $versions = az sig image-version list `
        --gallery-name $galleryName `
        --resource-group $resourceGroup `
        --gallery-image-definition $img `
        --query "[].name" -o json | ConvertFrom-Json
    
    if ($versions.Count -gt 0) {
        Write-Host "    • $img (versions: $($versions -join ', '))" -ForegroundColor Green
    } else {
        Write-Host "    • $img (no versions)" -ForegroundColor Yellow
    }
}
Write-Host ""

# List images available in DevCenter
Write-Host "Step 4: Images synced to DevCenter..." -ForegroundColor Yellow
$devCenterImages = az devcenter admin image list `
    --dev-center-name $devCenterName `
    --resource-group $resourceGroup `
    --query "[].name" -o json | ConvertFrom-Json

$customImages = $devCenterImages | Where-Object { $_ -in $computeImages }

if ($customImages.Count -eq 0) {
    Write-Host "  ⚠️  No custom images synced to DevCenter yet" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "IMPORTANT: Gallery sync can take time" -ForegroundColor Yellow
    Write-Host "  • Typical sync time: 5-30 minutes" -ForegroundColor Gray
    Write-Host "  • Maximum sync time: Up to 2 hours" -ForegroundColor Gray
    Write-Host ""
    Write-Host "What to do:" -ForegroundColor Cyan
    Write-Host "  1. Wait 5-10 minutes and run this script again" -ForegroundColor Gray
    Write-Host "  2. Once images appear here, run: .\03-create-definitions.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Currently showing $($devCenterImages.Count) total images (all Microsoft built-in)" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "  ✓ Found $($customImages.Count) custom image(s) synced:" -ForegroundColor Green
    foreach ($img in $customImages) {
        Write-Host "    • $img" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host " ✓ Gallery Sync Complete - Ready for Next Step" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step:" -ForegroundColor Cyan
    Write-Host "  Run: .\03-create-definitions.ps1" -ForegroundColor Gray
    Write-Host "  This will create DevBox definitions from your custom images" -ForegroundColor Gray
    Write-Host ""
}

