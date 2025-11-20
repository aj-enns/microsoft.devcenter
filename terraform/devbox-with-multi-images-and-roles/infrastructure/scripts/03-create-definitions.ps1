#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Create DevBox Definitions from definitions file

.DESCRIPTION
    This script reads the devbox-definitions.json file and creates DevBox definitions
    in the Azure DevCenter. Each definition links a gallery image to compute/storage
    settings that users can select when provisioning Dev Boxes.

    Managed by Operations Team - run after new images are built.

.PARAMETER DefinitionsPath
    Path to the devbox-definitions.json file
    Default: ../../images/definitions/devbox-definitions.json

.EXAMPLE
    .\03-create-definitions.ps1

.EXAMPLE
    .\03-create-definitions.ps1 -DefinitionsPath "..\..\images\definitions\devbox-definitions.json"
#>

[CmdletBinding()]
param(
    [string]$DefinitionsPath = "../../images/definitions/devbox-definitions.json"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Create DevBox Definitions" -ForegroundColor Cyan
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
    $location = $outputs.location.value
} finally {
    Set-Location $originalDir
}

Write-Host "  ✓ DevCenter: $devCenterName" -ForegroundColor Green
Write-Host "  ✓ Resource Group: $resourceGroup" -ForegroundColor Green
Write-Host "  ✓ Gallery: $galleryName" -ForegroundColor Green
Write-Host ""

# Read definitions file
Write-Host "Step 2: Reading DevBox definitions..." -ForegroundColor Yellow
if (-not (Test-Path $DefinitionsPath)) {
    Write-Host "  ❌ Definitions file not found: $DefinitionsPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected location: images/definitions/devbox-definitions.json" -ForegroundColor Yellow
    Write-Host "Development teams should create this file with their image configurations." -ForegroundColor Yellow
    exit 1
}

$definitionsFile = Get-Content $DefinitionsPath | ConvertFrom-Json
Write-Host "  ✓ Found $($definitionsFile.definitions.Count) definitions" -ForegroundColor Green
Write-Host ""

# Get gallery resource ID
Write-Host "Step 3: Getting gallery information..." -ForegroundColor Yellow
$gallery = az sig show `
    --resource-group $resourceGroup `
    --gallery-name $galleryName `
    --query "{id: id, name: name}" | ConvertFrom-Json

Write-Host "  ✓ Gallery ID: $($gallery.id)" -ForegroundColor Green
Write-Host ""

# Get existing definitions
Write-Host "Step 4: Checking existing definitions..." -ForegroundColor Yellow
$existingDefs = az devcenter admin devbox-definition list `
    --dev-center-name $devCenterName `
    --resource-group $resourceGroup `
    --query "[].{name:name, imageName:imageReference.id}" | ConvertFrom-Json

$existingDefNames = if ($existingDefs) { $existingDefs | ForEach-Object { $_.name } } else { @() }
Write-Host "  ✓ Found $($existingDefNames.Count) existing definitions" -ForegroundColor Green
Write-Host ""

# Get available SKUs and their capabilities
Write-Host "Step 5: Loading available DevBox SKUs..." -ForegroundColor Yellow
$availableSkus = az devcenter admin sku list --query "[].{name:name, capabilities:capabilities}" | ConvertFrom-Json
$skuLookup = @{}
foreach ($sku in $availableSkus) {
    $skuLookup[$sku.name] = $sku.capabilities
}
Write-Host "  ✓ Loaded $($availableSkus.Count) SKUs" -ForegroundColor Green
Write-Host ""

# Helper function to validate and auto-correct storage type
function Get-ValidStorageType {
    param(
        [string]$SkuName,
        [string]$RequestedStorage
    )
    
    # Extract storage from SKU name (e.g., "256ssd", "512ssd", "1024ssd")
    if ($SkuName -match '(\d+)ssd') {
        $skuStorageGB = $Matches[1]
        
        # If requested storage doesn't match SKU, use SKU's storage
        if ($RequestedStorage -match 'ssd_(\d+)gb') {
            $requestedGB = $Matches[1]
            if ($requestedGB -ne $skuStorageGB) {
                Write-Host "      ⚠️  Auto-correcting storage: $RequestedStorage -> ssd_${skuStorageGB}gb (matches SKU)" -ForegroundColor Yellow
                return "ssd_${skuStorageGB}gb"
            }
        }
        
        # If storage is generic "ssd", return SKU-specific value
        if ($RequestedStorage -eq "ssd") {
            return "ssd_${skuStorageGB}gb"
        }
        
        return $RequestedStorage
    }
    
    # If SKU doesn't have storage in name, use requested value
    return $RequestedStorage
}

# Create or update definitions
Write-Host "Step 6: Creating/updating DevBox definitions..." -ForegroundColor Yellow
Write-Host ""

$created = 0
$skipped = 0
$failed = 0

foreach ($def in $definitionsFile.definitions) {
    Write-Host "  Processing: $($def.name)" -ForegroundColor Cyan
    Write-Host "    Image: $($def.imageName) v$($def.imageVersion)" -ForegroundColor Gray
    Write-Host "    SKU: $($def.computeSku)" -ForegroundColor Gray
    
    # Validate SKU exists
    if (-not $skuLookup.ContainsKey($def.computeSku)) {
        Write-Host "    ✗ Invalid SKU: $($def.computeSku)" -ForegroundColor Red
        Write-Host "      Run: az devcenter admin sku list --query '[].name' -o table" -ForegroundColor Yellow
        $failed++
        Write-Host ""
        continue
    }
    
    # Auto-correct storage type based on SKU
    $originalStorage = $def.storageType
    $validatedStorage = Get-ValidStorageType -SkuName $def.computeSku -RequestedStorage $originalStorage
    
    Write-Host "    Storage: $validatedStorage" -ForegroundColor Gray
    
    # Check if definition already exists
    if ($def.name -in $existingDefNames) {
        Write-Host "    ⚠️  Definition already exists - skipping" -ForegroundColor Yellow
        $skipped++
        Write-Host ""
        continue
    }
    
    # Check if image version exists in DevCenter gallery (CustomImages)
    Write-Host "    Checking if image version exists in DevCenter..." -ForegroundColor Gray
    $imageCheck = az devcenter admin image-version show `
        --dev-center-name $devCenterName `
        --resource-group $resourceGroup `
        --gallery-name "CustomImages" `
        --image-name $def.imageName `
        --version-name $def.imageVersion `
        --query "{id: id}" 2>&1
    
    if ($LASTEXITCODE -ne 0 -or -not $imageCheck) {
        Write-Host "    ✗ Image version not found in DevCenter" -ForegroundColor Red
        Write-Host "      Image: $($def.imageName) v$($def.imageVersion)" -ForegroundColor Red
        Write-Host "      Development team needs to build this image first" -ForegroundColor Yellow
        $failed++
        Write-Host ""
        continue
    }
    
    $imageInfo = $imageCheck | ConvertFrom-Json
    $imageId = $imageInfo.id
    Write-Host "    ✓ Image found in DevCenter" -ForegroundColor Green
    
    # Create the definition
    Write-Host "    Creating DevBox definition..." -ForegroundColor Cyan
    
    try {
        $result = az devcenter admin devbox-definition create `
            --name $def.name `
            --dev-center-name $devCenterName `
            --resource-group $resourceGroup `
            --location $location `
            --image-reference id="$imageId" `
            --sku name="$($def.computeSku)" `
            --os-storage-type "$validatedStorage" `
            --hibernate-support "$($def.hibernationSupport)" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Definition created successfully" -ForegroundColor Green
            $created++
        } else {
            Write-Host "    ✗ Failed to create definition" -ForegroundColor Red
            Write-Host "      Error: $result" -ForegroundColor Red
            $failed++
        }
    } catch {
        Write-Host "    ✗ Exception: $_" -ForegroundColor Red
        $failed++
    }
    
    Write-Host ""
}

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host " ✓ DevBox Definitions Synchronization Complete" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  • Total definitions in file: $($definitionsFile.definitions.Count)" -ForegroundColor Gray
Write-Host "  • Created: $created" -ForegroundColor Green
Write-Host "  • Skipped (already exist): $skipped" -ForegroundColor Yellow
Write-Host "  • Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })
Write-Host ""

if ($failed -gt 0) {
    Write-Host "⚠️  Some definitions failed to create." -ForegroundColor Yellow
    Write-Host "   Make sure all images are built and available in the gallery." -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Run: .\04-sync-pools.ps1" -ForegroundColor Gray
Write-Host "     This will create DevBox pools that reference these definitions" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  2. Verify in Azure Portal:" -ForegroundColor Gray
Write-Host "     https://portal.azure.com -> DevCenter -> $devCenterName -> DevBox definitions" -ForegroundColor DarkGray
Write-Host ""
