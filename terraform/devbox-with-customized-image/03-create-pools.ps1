#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Step 3: Create DevCenter Pools
.DESCRIPTION
    This script generates a personalized create-pools.ps1 script with your specific
    values from Terraform state, then executes it to create DevCenter pools.
    
    The generated create-pools.ps1 is not tracked in git to keep your specific
    values private.
.NOTES
    Prerequisites:
    - Terraform state must exist (run step 1 first)
    - DevBox definitions must be created (run step 2 first)
    - Azure CLI must be installed and authenticated
#>

$ErrorActionPreference = "Stop"

Write-Host "`n🏊 Step 3: Create DevCenter Pools" -ForegroundColor Cyan
Write-Host "==================================`n" -ForegroundColor Cyan

# Check if get-pool-values.ps1 exists
if (-not (Test-Path "get-pool-values.ps1")) {
    Write-Host "❌ get-pool-values.ps1 not found in current directory." -ForegroundColor Red
    Write-Host "   Make sure you're running this from the correct folder.`n" -ForegroundColor Yellow
    exit 1
}

# Step 1: Generate the personalized script
Write-Host "📝 Generating personalized pool creation script..." -ForegroundColor Yellow
Write-Host "   This will read your Terraform state and create create-pools.ps1`n" -ForegroundColor Gray

try {
    & .\get-pool-values.ps1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "`n❌ Failed to generate create-pools.ps1" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "`n❌ Error running get-pool-values.ps1: $_" -ForegroundColor Red
    exit 1
}

# Step 2: Check if the script was created
if (-not (Test-Path "create-pools.ps1")) {
    Write-Host "`n❌ create-pools.ps1 was not generated successfully." -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Personalized script created successfully!" -ForegroundColor Green
Write-Host "`n📋 You can review the generated create-pools.ps1 before running it." -ForegroundColor Cyan
Write-Host "`nWould you like to:" -ForegroundColor Yellow
Write-Host "  [R] Run create-pools.ps1 now" -ForegroundColor White
Write-Host "  [V] View create-pools.ps1 first" -ForegroundColor White
Write-Host "  [Q] Quit (you can run create-pools.ps1 manually later)" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter your choice (R/V/Q)"

switch ($choice.ToUpper()) {
    "R" {
        Write-Host "`n🚀 Running create-pools.ps1...`n" -ForegroundColor Green
        & .\create-pools.ps1
    }
    "V" {
        Write-Host "`n📄 Opening create-pools.ps1 for review...`n" -ForegroundColor Cyan
        code create-pools.ps1
        Write-Host "After reviewing, you can run it with: .\create-pools.ps1`n" -ForegroundColor Yellow
    }
    "Q" {
        Write-Host "`n👍 No problem! You can run it later with: .\create-pools.ps1`n" -ForegroundColor Cyan
    }
    default {
        Write-Host "`n⚠️  Invalid choice. You can run create-pools.ps1 manually with: .\create-pools.ps1`n" -ForegroundColor Yellow
    }
}
