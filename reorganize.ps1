#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reorganizes the repository structure into bicep/ and terraform/ folders
    
.DESCRIPTION
    This script reorganizes the Microsoft DevCenter repository to separate
    Bicep-based examples into a bicep/ folder and Terraform-based examples
    into a terraform/ folder for better organization.
    
.PARAMETER Preview
    Shows what would be done without actually moving files
    
.EXAMPLE
    .\reorganize.ps1 -Preview
    Shows the reorganization plan without making changes
    
.EXAMPLE
    .\reorganize.ps1
    Performs the actual reorganization
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Preview
)

$ErrorActionPreference = "Stop"

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Microsoft DevCenter Repository Reorganization" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Verify we're in the right directory
$repoRoot = $PSScriptRoot
if (-not (Test-Path (Join-Path $repoRoot ".git"))) {
    Write-Error "This script must be run from the repository root"
    exit 1
}

Write-Host "Repository root: $repoRoot" -ForegroundColor Yellow
Write-Host ""

# Define the reorganization plan
$bicepFolders = @(
    "deployment-environments",
    "devbox-quick-start",
    "devbox-ready-to-code-image",
    "devbox-with-builtin-image",
    "devbox-with-customized-image"
)

$terraformMoves = @{
    "devbox-with-customized-image-tf" = "devbox-with-customized-image"
}

# Step 1: Create new directories
Write-Host "Step 1: Creating new directory structure..." -ForegroundColor Yellow
Write-Host ""

$newDirs = @("bicep", "terraform")
foreach ($dir in $newDirs) {
    $fullPath = Join-Path $repoRoot $dir
    if (Test-Path $fullPath) {
        Write-Host "  ✓ Directory already exists: $dir" -ForegroundColor Gray
    } else {
        if ($PSCmdlet.ShouldProcess($dir, "Create directory")) {
            New-Item -Path $fullPath -ItemType Directory -Force | Out-Null
            Write-Host "  ✓ Created: $dir" -ForegroundColor Green
        } else {
            Write-Host "  [WhatIf] Would create: $dir" -ForegroundColor Cyan
        }
    }
}
Write-Host ""

# Step 2: Move Bicep examples
Write-Host "Step 2: Moving Bicep examples to bicep/..." -ForegroundColor Yellow
Write-Host ""

foreach ($folder in $bicepFolders) {
    $source = Join-Path $repoRoot $folder
    $dest = Join-Path $repoRoot "bicep\$folder"
    
    if (-not (Test-Path $source)) {
        Write-Host "  ⚠️  Source not found: $folder (skipping)" -ForegroundColor Yellow
        continue
    }
    
    if (Test-Path $dest) {
        Write-Host "  ⚠️  Destination already exists: bicep\$folder (skipping)" -ForegroundColor Yellow
        continue
    }
    
    if ($PSCmdlet.ShouldProcess("$folder → bicep\$folder", "Move directory")) {
        Move-Item -Path $source -Destination $dest -Force
        Write-Host "  ✓ Moved: $folder → bicep\$folder" -ForegroundColor Green
    } else {
        Write-Host "  [WhatIf] Would move: $folder → bicep\$folder" -ForegroundColor Cyan
    }
}
Write-Host ""

# Step 3: Move Terraform examples
Write-Host "Step 3: Moving Terraform examples to terraform/..." -ForegroundColor Yellow
Write-Host ""

foreach ($move in $terraformMoves.GetEnumerator()) {
    $source = Join-Path $repoRoot $move.Key
    $dest = Join-Path $repoRoot "terraform\$($move.Value)"
    
    if (-not (Test-Path $source)) {
        Write-Host "  ⚠️  Source not found: $($move.Key) (skipping)" -ForegroundColor Yellow
        continue
    }
    
    if (Test-Path $dest) {
        Write-Host "  ⚠️  Destination already exists: terraform\$($move.Value) (skipping)" -ForegroundColor Yellow
        continue
    }
    
    if ($PSCmdlet.ShouldProcess("$($move.Key) → terraform\$($move.Value)", "Move directory")) {
        Move-Item -Path $source -Destination $dest -Force
        Write-Host "  ✓ Moved: $($move.Key) → terraform\$($move.Value)" -ForegroundColor Green
    } else {
        Write-Host "  [WhatIf] Would move: $($move.Key) → terraform\$($move.Value)" -ForegroundColor Cyan
    }
}
Write-Host ""

# Summary
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Reorganization Summary" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

if ($Preview -or $WhatIfPreference) {
    Write-Host "✓ Preview mode - no changes were made" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To perform the actual reorganization, run:" -ForegroundColor White
    Write-Host "  .\reorganize.ps1" -ForegroundColor Cyan
} else {
    Write-Host "✓ Reorganization complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "New structure:" -ForegroundColor White
    Write-Host "  bicep/" -ForegroundColor Cyan
    foreach ($folder in $bicepFolders) {
        Write-Host "    └── $folder" -ForegroundColor Gray
    }
    Write-Host "  terraform/" -ForegroundColor Cyan
    foreach ($move in $terraformMoves.GetEnumerator()) {
        Write-Host "    └── $($move.Value)" -ForegroundColor Gray
    }
}
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review the new structure" -ForegroundColor White
Write-Host "  2. Update any documentation or scripts that reference old paths" -ForegroundColor White
Write-Host "  3. Check .github/workflows for any path references" -ForegroundColor White
Write-Host "  4. Commit the reorganization:" -ForegroundColor White
Write-Host "     git add ." -ForegroundColor Cyan
Write-Host "     git commit -m 'Reorganize repository into bicep/ and terraform/ folders'" -ForegroundColor Cyan
Write-Host ""
