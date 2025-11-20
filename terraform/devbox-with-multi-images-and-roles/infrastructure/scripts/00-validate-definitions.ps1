#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Validate DevBox definitions configuration

.DESCRIPTION
    This script validates the devbox-definitions.json file for common issues:
    - Invalid SKU names
    - Storage type mismatches with SKU
    - Missing images in gallery
    - Orphaned pool references
    
    Run this before 03-create-definitions.ps1 to catch configuration errors early.

.PARAMETER DefinitionsPath
    Path to the devbox-definitions.json file
    Default: ../../images/definitions/devbox-definitions.json

.PARAMETER Fix
    Automatically fix common issues (storage type mismatches)

.EXAMPLE
    .\00-validate-definitions.ps1

.EXAMPLE
    .\00-validate-definitions.ps1 -Fix
#>

[CmdletBinding()]
param(
    [string]$DefinitionsPath = "../../images/definitions/devbox-definitions.json",
    [switch]$Fix
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Validate DevBox Definitions" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Read Terraform outputs
Write-Host "Step 1: Reading infrastructure configuration..." -ForegroundColor Yellow
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
Write-Host "  ✓ Gallery: $galleryName" -ForegroundColor Green
Write-Host ""

# Read definitions file
Write-Host "Step 2: Reading definitions file..." -ForegroundColor Yellow
if (-not (Test-Path $DefinitionsPath)) {
    Write-Host "  ✗ File not found: $DefinitionsPath" -ForegroundColor Red
    exit 1
}

$definitionsFile = Get-Content $DefinitionsPath -Raw | ConvertFrom-Json
Write-Host "  ✓ Found $($definitionsFile.definitions.Count) definitions" -ForegroundColor Green
Write-Host "  ✓ Found $($definitionsFile.pools.Count) pools" -ForegroundColor Green
Write-Host ""

# Get available SKUs
Write-Host "Step 3: Loading available DevBox SKUs..." -ForegroundColor Yellow
$availableSkusRaw = az devcenter admin sku list --query "[].name" -o tsv
$availableSkus = $availableSkusRaw -split "`n" | Where-Object { $_ }
$skuSet = [System.Collections.Generic.HashSet[string]]::new()
$availableSkus | ForEach-Object { $skuSet.Add($_) | Out-Null }
Write-Host "  ✓ Loaded $($skuSet.Count) SKUs" -ForegroundColor Green
Write-Host ""

# Get available images
Write-Host "Step 4: Checking available images in gallery..." -ForegroundColor Yellow
$images = az sig image-definition list `
    --gallery-name $galleryName `
    --resource-group $resourceGroup `
    --query "[].{name:name, versions:''}" | ConvertFrom-Json

$imageVersions = @{}
foreach ($img in $images) {
    $versions = az sig image-version list `
        --gallery-name $galleryName `
        --resource-group $resourceGroup `
        --gallery-image-definition $img.name `
        --query "[].name" -o tsv
    $imageVersions[$img.name] = $versions
}
Write-Host "  ✓ Found $($images.Count) images with $($imageVersions.Values.Count) total versions" -ForegroundColor Green
Write-Host ""

# Validation
Write-Host "Step 5: Validating definitions..." -ForegroundColor Yellow
Write-Host ""

$errors = @()
$warnings = @()
$fixes = @()

foreach ($def in $definitionsFile.definitions) {
    Write-Host "  Checking: $($def.name)" -ForegroundColor Cyan
    
    # Validate SKU
    if (-not $skuSet.Contains($def.computeSku)) {
        $errors += "  ✗ $($def.name): Invalid SKU '$($def.computeSku)'"
        Write-Host "    ✗ Invalid SKU: $($def.computeSku)" -ForegroundColor Red
    } else {
        Write-Host "    ✓ SKU valid: $($def.computeSku)" -ForegroundColor Green
    }
    
    # Validate storage type matches SKU
    if ($def.computeSku -match '(\d+)ssd') {
        $skuStorageGB = $Matches[1]
        $expectedStorage = "ssd_${skuStorageGB}gb"
        
        if ($def.storageType -ne $expectedStorage -and $def.storageType -ne "ssd") {
            $warnings += "  ⚠️  $($def.name): Storage mismatch - SKU has ${skuStorageGB}GB but config has '$($def.storageType)'"
            Write-Host "    ⚠️  Storage mismatch: $($def.storageType) (SKU requires $expectedStorage)" -ForegroundColor Yellow
            
            if ($Fix) {
                $fixes += @{
                    DefinitionName = $def.name
                    Field = "storageType"
                    OldValue = $def.storageType
                    NewValue = $expectedStorage
                }
                $def.storageType = $expectedStorage
                Write-Host "       → Fixed to: $expectedStorage" -ForegroundColor Green
            }
        } else {
            Write-Host "    ✓ Storage type valid" -ForegroundColor Green
        }
    }
    
    # Validate image exists
    if (-not $imageVersions.ContainsKey($def.imageName)) {
        $errors += "  ✗ $($def.name): Image '$($def.imageName)' not found in gallery"
        Write-Host "    ✗ Image not found: $($def.imageName)" -ForegroundColor Red
    } elseif ($def.imageVersion -notin $imageVersions[$def.imageName]) {
        $errors += "  ✗ $($def.name): Image version '$($def.imageVersion)' not found"
        Write-Host "    ✗ Image version not found: $($def.imageVersion)" -ForegroundColor Red
        Write-Host "      Available versions: $($imageVersions[$def.imageName] -join ', ')" -ForegroundColor Gray
    } else {
        Write-Host "    ✓ Image exists: $($def.imageName) v$($def.imageVersion)" -ForegroundColor Green
    }
    
    Write-Host ""
}

# Validate pool references
Write-Host "  Checking pool references..." -ForegroundColor Cyan
$definitionNames = $definitionsFile.definitions | ForEach-Object { $_.name }
foreach ($pool in $definitionsFile.pools) {
    if ($pool.definitionName -notin $definitionNames) {
        $errors += "  ✗ Pool '$($pool.name)' references undefined definition '$($pool.definitionName)'"
        Write-Host "    ✗ Pool '$($pool.name)': Orphaned reference to '$($pool.definitionName)'" -ForegroundColor Red
    } else {
        Write-Host "    ✓ Pool '$($pool.name)' -> '$($pool.definitionName)'" -ForegroundColor Green
    }
}
Write-Host ""

# Apply fixes if requested
if ($Fix -and $fixes.Count -gt 0) {
    Write-Host "Applying fixes..." -ForegroundColor Yellow
    $definitionsFile | ConvertTo-Json -Depth 10 | Set-Content $DefinitionsPath
    Write-Host "  ✓ Saved $($fixes.Count) fix(es) to $DefinitionsPath" -ForegroundColor Green
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host " Validation Summary" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "✓ All validations passed!" -ForegroundColor Green
} else {
    if ($errors.Count -gt 0) {
        Write-Host "Errors ($($errors.Count)):" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host $err -ForegroundColor Red
        }
        Write-Host ""
    }
    
    if ($warnings.Count -gt 0) {
        Write-Host "Warnings ($($warnings.Count)):" -ForegroundColor Yellow
        foreach ($warn in $warnings) {
            Write-Host $warn -ForegroundColor Yellow
        }
        Write-Host ""
        
        if (-not $Fix) {
            Write-Host "Tip: Run with -Fix to automatically correct storage mismatches" -ForegroundColor Cyan
            Write-Host ""
        }
    }
}

if ($fixes.Count -gt 0) {
    Write-Host "Applied Fixes ($($fixes.Count)):" -ForegroundColor Green
    foreach ($fix in $fixes) {
        Write-Host "  • $($fix.DefinitionName).$($fix.Field): $($fix.OldValue) → $($fix.NewValue)" -ForegroundColor Green
    }
    Write-Host ""
}

Write-Host "Next Steps:" -ForegroundColor Cyan
if ($errors.Count -eq 0) {
    Write-Host "  1. .\03-create-definitions.ps1  # Create DevBox definitions" -ForegroundColor Gray
    Write-Host "  2. .\04-sync-pools.ps1          # Create pools" -ForegroundColor Gray
} else {
    Write-Host "  Fix the errors above, then:" -ForegroundColor Yellow
    Write-Host "    1. Build missing images (if needed)" -ForegroundColor Gray
    Write-Host "    2. Update devbox-definitions.json" -ForegroundColor Gray
    Write-Host "    3. Re-run this validation" -ForegroundColor Gray
}
Write-Host ""

exit $(if ($errors.Count -gt 0) { 1 } else { 0 })
