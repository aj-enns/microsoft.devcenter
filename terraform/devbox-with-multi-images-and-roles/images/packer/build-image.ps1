<#
.SYNOPSIS
    Build DevBox Custom Image
    
.DESCRIPTION
    This script builds a custom DevBox image using Packer.
    Managed by Development Teams.
    
    Teams can use this to build their custom images which will be
    automatically added to the gallery and made available for DevBox definitions.
    
.PARAMETER ImageType
    The team image to build (vscode, java, dotnet)
    
.PARAMETER ValidateOnly
    Only validate the Packer template without building
    
.EXAMPLE
    .\build-image.ps1 -ImageType vscode
    
.EXAMPLE
    .\build-image.ps1 -ImageType vscode -ValidateOnly
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("vscode", "java", "dotnet")]
    [string]$ImageType,
    
    [switch]$ValidateOnly
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Build DevBox Custom Image: $ImageType" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Determine file paths
$packerFile = "teams\$ImageType-devbox.pkr.hcl"
$varsFile = "teams\$ImageType-variables.pkrvars.hcl"

if (-not (Test-Path $packerFile)) {
    Write-Host "❌ Packer file not found: $packerFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $varsFile)) {
    Write-Host "❌ Variables file not found: $varsFile" -ForegroundColor Red
    Write-Host ""
    Write-Host "Create it from the example:" -ForegroundColor Yellow
    Write-Host "  cp teams\$ImageType-variables.pkrvars.hcl.example $varsFile" -ForegroundColor Gray
    exit 1
}

# Check Azure CLI authentication
Write-Host "Step 1: Checking Azure CLI authentication..." -ForegroundColor Yellow
try {
    $account = az account show 2>&1 | ConvertFrom-Json
    Write-Host "  ✓ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "  ✓ Subscription: $($account.name)" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Not logged in to Azure CLI" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run: az login" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Initialize Packer
Write-Host "Step 2: Initializing Packer..." -ForegroundColor Yellow
packer init $packerFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Packer init failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Packer initialized" -ForegroundColor Green
Write-Host ""

# Validate Packer template
Write-Host "Step 3: Validating Packer template..." -ForegroundColor Yellow
packer validate -var-file=$varsFile $packerFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Packer validation failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Template is valid" -ForegroundColor Green
Write-Host ""

if ($ValidateOnly) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  ✓ Validation Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    exit 0
}

# Build image
Write-Host "Step 4: Building image..." -ForegroundColor Yellow
Write-Host "  This may take 30-60 minutes depending on image size and complexity" -ForegroundColor Gray
Write-Host ""

$buildStart = Get-Date
packer build -var-file=$varsFile $packerFile

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  ❌ Image build failed" -ForegroundColor Red
    exit 1
}

$buildEnd = Get-Date
$duration = $buildEnd - $buildStart

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✓ Image Build Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Build time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Update devbox-definitions.json with the new image version" -ForegroundColor Gray
Write-Host "  2. Operations team will run 04-sync-pools.ps1 to create pools" -ForegroundColor Gray
Write-Host "  3. Or create a PR and pools will be auto-created via CI/CD" -ForegroundColor Gray
Write-Host ""
