# Build script for IntelliJ DevBox Image
# This script builds the IntelliJ IDEA Community Edition development image

param(
    [string]$VariablesFile = "intellij-variables.pkrvars.hcl",
    [switch]$Debug = $false,
    [switch]$Validate = $false
)

$ErrorActionPreference = "Stop"

Write-Host "=== IntelliJ DevBox Image Build Script ===" -ForegroundColor Green
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Change to packer directory
$PackerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $PackerDir

try {
    # Verify required files exist
    if (!(Test-Path "intellij-devbox.pkr.hcl")) {
        throw "Packer configuration file 'intellij-devbox.pkr.hcl' not found"
    }
    
    if (!(Test-Path $VariablesFile)) {
        throw "Variables file '$VariablesFile' not found"
    }
    
    Write-Host "✓ Packer configuration files found" -ForegroundColor Green
    
    # Check Azure CLI authentication
    Write-Host "Checking Azure CLI authentication..." -ForegroundColor Yellow
    try {
        $account = az account show --query "user.name" --output tsv 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Azure CLI authenticated as: $account" -ForegroundColor Green
        } else {
            throw "Azure CLI not authenticated"
        }
    }
    catch {
        Write-Host "❌ Azure CLI authentication failed" -ForegroundColor Red
        Write-Host "Please run: az login" -ForegroundColor Yellow
        exit 1
    }
    
    # Initialize Packer (if needed)
    Write-Host "Initializing Packer..." -ForegroundColor Yellow
    packer init intellij-devbox.pkr.hcl
    if ($LASTEXITCODE -ne 0) {
        throw "Packer initialization failed"
    }
    Write-Host "✓ Packer initialized" -ForegroundColor Green
    
    # Validate configuration
    Write-Host "Validating Packer configuration..." -ForegroundColor Yellow
    if ($Debug) {
        packer validate -var-file="$VariablesFile" intellij-devbox.pkr.hcl
    } else {
        packer validate -var-file="$VariablesFile" intellij-devbox.pkr.hcl 2>&1 | Out-Null
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Packer configuration validation failed"
    }
    Write-Host "✓ Packer configuration valid" -ForegroundColor Green
    
    if ($Validate) {
        Write-Host "✓ Validation complete - configuration is valid" -ForegroundColor Green
        return
    }
    
    # Build the image
    Write-Host "Starting image build..." -ForegroundColor Yellow
    Write-Host "This will take approximately 45-60 minutes for IntelliJ image" -ForegroundColor Gray
    
    $buildArgs = @(
        "build",
        "-var-file=$VariablesFile"
    )
    
    if ($Debug) {
        $buildArgs += "-debug"
    }
    
    $buildArgs += "intellij-devbox.pkr.hcl"
    
    $buildStartTime = Get-Date
    & packer @buildArgs
    
    if ($LASTEXITCODE -eq 0) {
        $buildDuration = (Get-Date) - $buildStartTime
        Write-Host "✓ Image build completed successfully!" -ForegroundColor Green
        Write-Host "Build duration: $($buildDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Verify the image in Azure Compute Gallery" -ForegroundColor White
        Write-Host "2. Test the Dev Box definition in DevCenter" -ForegroundColor White
        Write-Host "3. Create a Dev Box from the IntelliJ image" -ForegroundColor White
    } else {
        throw "Image build failed"
    }
}
catch {
    Write-Host "❌ Build failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Pop-Location
}