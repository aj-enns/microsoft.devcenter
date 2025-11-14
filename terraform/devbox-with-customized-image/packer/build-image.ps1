#!/usr/bin/env pwsh
# Build script for Packer image creation

param(
    [string]$Action = "build",
    [string]$ImageType = "vscode",  # "vscode", "visualstudio", "intellij", or "all"
    [string]$VarFile = "",
    [switch]$Debug,
    [switch]$Force
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "$Color$Message$Reset"
}

function Get-ImageConfig {
    param([string]$ImageType)
    
    switch ($ImageType.ToLower()) {
        "vscode" {
            return @{
                ConfigFile = "vscode-devbox.pkr.hcl"
                VarFile = if ($VarFile) { $VarFile } else { "vscode-variables.pkrvars.hcl" }
                Name = "VS Code DevBox"
            }
        }
        "visualstudio" {
            return @{
                ConfigFile = "visualstudio-devbox.pkr.hcl"
                VarFile = if ($VarFile) { $VarFile } else { "visualstudio-variables.pkrvars.hcl" }
                Name = "Visual Studio DevBox"
            }
        }
        "intellij" {
            return @{
                ConfigFile = "intellij-devbox.pkr.hcl" 
                VarFile = if ($VarFile) { $VarFile } else { "intellij-variables.pkrvars.hcl" }
                Name = "IntelliJ DevBox"
            }
        }
        default {
            throw "Unknown image type: $ImageType. Valid types: vscode, visualstudio, intellij"
        }
    }
}

function Test-Prerequisites {
    param([hashtable]$Config)
    
    Write-ColorOutput "🔍 Checking prerequisites for $($Config.Name)..." $Yellow
    
    # Check if Packer is installed
    try {
        $packerVersion = packer version
        Write-ColorOutput "✅ Packer found: $packerVersion" $Green
    }
    catch {
        Write-ColorOutput "❌ Packer not found. Please install Packer first." $Red
        Write-ColorOutput "   Download from: https://www.packer.io/downloads" $Yellow
        exit 1
    }
    
    # Check if Azure CLI is available
    try {
        $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
        Write-ColorOutput "✅ Azure CLI found: $azVersion" $Green
    }
    catch {
        Write-ColorOutput "⚠️  Azure CLI not found. You may need to authenticate different." $Yellow
    }
    
    # Check if config file exists
    if (-not (Test-Path $Config.ConfigFile)) {
        Write-ColorOutput "❌ Packer config not found: $($Config.ConfigFile)" $Red
        exit 1
    }
    
    # Check if variables file exists
    if (-not (Test-Path $Config.VarFile)) {
        Write-ColorOutput "❌ Variables file not found: $($Config.VarFile)" $Red
        Write-ColorOutput "   Create $($Config.VarFile) with your Azure resource details." $Yellow
        exit 1
    }
    
    Write-ColorOutput "✅ Prerequisites check passed for $($Config.Name)!" $Green
}

function Initialize-Packer {
    param([hashtable]$Config)
    
    Write-ColorOutput "🚀 Initializing Packer for $($Config.Name)..." $Yellow
    try {
        packer init $Config.ConfigFile
        Write-ColorOutput "✅ Packer initialized successfully!" $Green
    }
    catch {
        Write-ColorOutput "❌ Failed to initialize Packer: $_" $Red
        exit 1
    }
}

function Test-PackerConfig {
    param([hashtable]$Config)
    
    Write-ColorOutput "🔍 Validating Packer configuration for $($Config.Name)..." $Yellow
    try {
        $validateArgs = @("validate")
        $validateArgs += @("-var-file=$($Config.VarFile)")
        $validateArgs += $Config.ConfigFile
        
        & packer @validateArgs
        Write-ColorOutput "✅ Packer configuration is valid!" $Green
    }
    catch {
        Write-ColorOutput "❌ Packer configuration validation failed: $_" $Red
        exit 1
    }
}

function Build-PackerImage {
    param([hashtable]$Config)
    
    Write-ColorOutput "🏗️  Starting Packer build for $($Config.Name)..." $Yellow
    Write-ColorOutput "   This may take 30-60 minutes depending on the configuration." $Yellow
    
    try {
        $buildArgs = @("build")
        if ($Debug) { $buildArgs += "-debug" }
        if ($Force) { $buildArgs += "-force" }
        $buildArgs += @("-var-file=$($Config.VarFile)")
        $buildArgs += $Config.ConfigFile
        
        $buildStart = Get-Date
        & packer @buildArgs
        $buildDuration = (Get-Date) - $buildStart
        
        Write-ColorOutput "✅ Image build completed successfully for $($Config.Name)!" $Green
        Write-ColorOutput "   Build duration: $($buildDuration.ToString('hh\:mm\:ss'))" $Yellow
    }
    catch {
        Write-ColorOutput "❌ Image build failed for $($Config.Name): $_" $Red
        exit 1
    }
}

function Show-Usage {
    Write-Host @"
Packer Build Script for DevCenter Custom Images

Usage: .\build-image.ps1 [OPTIONS]

Options:
  -Action <action>     Action to perform: init, validate, build, or all (default: build)
  -ImageType <type>    Image type to build: vscode, intellij, or both (default: vscode)
  -VarFile <file>      Variables file to use (overrides default for image type)
  -Debug              Enable debug mode for Packer
  -Force              Force build even if artifacts exist
  -Help               Show this help message

Image Types:
  vscode              VS Code development image (vscode-devbox.pkr.hcl)
  visualstudio        Visual Studio 2022 + VS Code image (visualstudio-devbox.pkr.hcl)
  intellij            IntelliJ IDEA + WSL image (intellij-devbox.pkr.hcl)
  all                 Build all image types sequentially

Examples:
  .\build-image.ps1                                         # Build VS Code image
  .\build-image.ps1 -ImageType visualstudio                # Build Visual Studio image
  .\build-image.ps1 -ImageType intellij                    # Build IntelliJ image
  .\build-image.ps1 -ImageType all                         # Build all images
  .\build-image.ps1 -Action validate -ImageType vscode     # Validate VS Code config
  .\build-image.ps1 -Action all -ImageType visualstudio    # Init, validate, and build Visual Studio
  .\build-image.ps1 -Debug -Force -ImageType all           # Debug mode, force rebuild all

Prerequisites:
  1. Install Packer: https://www.packer.io/downloads
  2. Authenticate with Azure (az login or environment variables)
  3. Create variables files: vscode-variables.pkrvars.hcl, visualstudio-variables.pkrvars.hcl, and intellij-variables.pkrvars.hcl
  4. Ensure the Azure Compute Gallery and Image Definitions exist (created by Terraform)
"@
}

function Process-ImageType {
    param([string]$Action, [string]$ImageType)
    
    $config = Get-ImageConfig -ImageType $ImageType
    
    switch ($Action.ToLower()) {
        "init" {
            Test-Prerequisites -Config $config
            Initialize-Packer -Config $config
        }
        "validate" {
            Test-Prerequisites -Config $config
            Test-PackerConfig -Config $config
        }
        "build" {
            Test-Prerequisites -Config $config
            Build-PackerImage -Config $config
        }
        "all" {
            Test-Prerequisites -Config $config
            Initialize-Packer -Config $config
            Test-PackerConfig -Config $config
            Build-PackerImage -Config $config
        }
        default {
            Write-ColorOutput "❌ Unknown action: $Action" $Red
            Write-ColorOutput "   Valid actions: init, validate, build, all" $Yellow
            Show-Usage
            exit 1
        }
    }
}

# Main execution
try {
    if ($args -contains "-Help" -or $args -contains "--help" -or $args -contains "-h") {
        Show-Usage
        exit 0
    }
    
    # Change to packer directory
    $packerDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $packerDir
    
    Write-ColorOutput "🎯 Packer DevCenter Image Build" $Green
    Write-ColorOutput "   Action: $Action" $Yellow
    Write-ColorOutput "   Image Type: $ImageType" $Yellow
    Write-ColorOutput ""
    
    # Process based on image type
    if ($ImageType.ToLower() -eq "all") {
        Write-ColorOutput "🔥 Building all image types..." $Green
        
        Write-ColorOutput "=== Building VS Code Image ===" $Yellow
        Process-ImageType -Action $Action -ImageType "vscode"
        
        Write-ColorOutput ""
        Write-ColorOutput "=== Building Visual Studio Image ===" $Yellow
        Process-ImageType -Action $Action -ImageType "visualstudio"
        
        Write-ColorOutput ""
        Write-ColorOutput "=== Building IntelliJ Image ===" $Yellow
        Process-ImageType -Action $Action -ImageType "intellij"
    }
    else {
        Process-ImageType -Action $Action -ImageType $ImageType
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "🎉 All operations completed successfully!" $Green
}
catch {
    Write-ColorOutput "❌ Script failed: $_" $Red
    exit 1
}