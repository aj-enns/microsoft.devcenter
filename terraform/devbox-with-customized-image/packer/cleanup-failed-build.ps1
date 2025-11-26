#!/usr/bin/env pwsh
# Cleanup script for failed Packer builds

param(
    [switch]$WhatIf,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Colors
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "$Color$Message$Reset"
}

Write-ColorOutput "🧹 Packer Build Cleanup Script" $Green
Write-ColorOutput ""

# Find leftover Packer resource groups
Write-ColorOutput "🔍 Looking for Packer resource groups..." $Yellow
$packerRGs = az group list --query "[?starts_with(name, 'pkr-Resource-Group')].{Name:name, Location:location, Tags:tags}" -o json | ConvertFrom-Json

if ($packerRGs.Count -eq 0) {
    Write-ColorOutput "✅ No Packer resource groups found!" $Green
} else {
    Write-ColorOutput "Found $($packerRGs.Count) Packer resource group(s):" $Yellow
    $packerRGs | ForEach-Object {
        Write-ColorOutput "  - $($_.Name) ($($_.Location))" $Yellow
    }
    
    if ($WhatIf) {
        Write-ColorOutput "`n[WhatIf] Would delete these resource groups" $Yellow
    } else {
        if (-not $Force) {
            $confirm = Read-Host "`nDelete these resource groups? (yes/no)"
            if ($confirm -ne "yes") {
                Write-ColorOutput "❌ Cancelled by user" $Red
                exit 0
            }
        }
        
        Write-ColorOutput "`n🗑️  Deleting resource groups..." $Yellow
        foreach ($rg in $packerRGs) {
            Write-ColorOutput "  Deleting $($rg.Name)..." $Yellow
            az group delete --name $rg.Name --yes --no-wait
            Write-ColorOutput "  ✅ Delete initiated for $($rg.Name)" $Green
        }
    }
}

# Check for failed image versions
Write-ColorOutput "`n🔍 Checking for failed image versions..." $Yellow

$resourceGroup = "rg-devbox-learn-demo-tf"
$galleryName = "galwx1xi0xrsrl5c"
$imageDefinition = "IntelliJDevImage"

try {
    $imageVersions = az sig image-version list `
        --resource-group $resourceGroup `
        --gallery-name $galleryName `
        --gallery-image-definition $imageDefinition `
        --query "[].{Name:name, State:provisioningState, Publishing:publishingProfile.targetRegions[0].storageAccountType}" -o json | ConvertFrom-Json
    
    $failedVersions = $imageVersions | Where-Object { $_.State -ne "Succeeded" }
    
    if ($failedVersions.Count -eq 0) {
        Write-ColorOutput "✅ No failed image versions found!" $Green
    } else {
        Write-ColorOutput "Found $($failedVersions.Count) failed/incomplete image version(s):" $Yellow
        $failedVersions | ForEach-Object {
            Write-ColorOutput "  - Version $($_.Name) - State: $($_.State)" $Yellow
        }
        
        if ($WhatIf) {
            Write-ColorOutput "`n[WhatIf] Would delete these image versions" $Yellow
        } else {
            if (-not $Force) {
                $confirm = Read-Host "`nDelete these failed image versions? (yes/no)"
                if ($confirm -ne "yes") {
                    Write-ColorOutput "❌ Cancelled by user" $Red
                    exit 0
                }
            }
            
            Write-ColorOutput "`n🗑️  Deleting failed image versions..." $Yellow
            foreach ($version in $failedVersions) {
                Write-ColorOutput "  Deleting version $($version.Name)..." $Yellow
                az sig image-version delete `
                    --resource-group $resourceGroup `
                    --gallery-name $galleryName `
                    --gallery-image-definition $imageDefinition `
                    --gallery-image-version $version.Name
                Write-ColorOutput "  ✅ Deleted version $($version.Name)" $Green
            }
        }
    }
} catch {
    Write-ColorOutput "⚠️  Could not check image versions: $_" $Yellow
}

Write-ColorOutput "`n✅ Cleanup complete!" $Green
Write-ColorOutput ""
Write-ColorOutput "💡 Tips:" $Yellow
Write-ColorOutput "  - Use -WhatIf to see what would be deleted without actually deleting" $Yellow
Write-ColorOutput "  - Use -Force to skip confirmation prompts" $Yellow
