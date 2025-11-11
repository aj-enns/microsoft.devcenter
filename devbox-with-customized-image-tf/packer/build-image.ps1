#!/usr/bin/env pwsh
# Build script for Packer image creation

param(
    [string]$Action = "build",
    [string]$VarFile = "variables.pkrvars.hcl",
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

function Test-Prerequisites {
    Write-ColorOutput "🔍 Checking prerequisites..." $Yellow
    
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
        Write-ColorOutput "⚠️  Azure CLI not found. You may need to authenticate differently." $Yellow
    }
    
    # Check if variables file exists
    if (-not (Test-Path $VarFile)) {
        Write-ColorOutput "❌ Variables file not found: $VarFile" $Red
        Write-ColorOutput "   Copy variables.pkrvars.hcl.example to $VarFile and customize it." $Yellow
        exit 1
    }
    
    Write-ColorOutput "✅ Prerequisites check passed!" $Green
}

function Initialize-Packer {
    Write-ColorOutput "🚀 Initializing Packer..." $Yellow
    try {
        packer init .
        Write-ColorOutput "✅ Packer initialized successfully!" $Green
    }
    catch {
        Write-ColorOutput "❌ Failed to initialize Packer: $_" $Red
        exit 1
    }
}

function Validate-PackerConfig {
    Write-ColorOutput "🔍 Validating Packer configuration..." $Yellow
    try {
        $validateArgs = @("validate")
        if ($VarFile) { $validateArgs += @("-var-file=$VarFile") }
        $validateArgs += "."
        
        & packer @validateArgs
        Write-ColorOutput "✅ Packer configuration is valid!" $Green
    }
    catch {
        Write-ColorOutput "❌ Packer configuration validation failed: $_" $Red
        exit 1
    }
}

function Build-Image {
    Write-ColorOutput "🏗️  Starting Packer build..." $Yellow
    Write-ColorOutput "   This may take 30-60 minutes depending on the configuration." $Yellow
    
    try {
        $buildArgs = @("build")
        if ($Debug) { $buildArgs += "-debug" }
        if ($Force) { $buildArgs += "-force" }
        if ($VarFile) { $buildArgs += "-var-file=$VarFile" }
        $buildArgs += "."
        
        & packer @buildArgs
        Write-ColorOutput "✅ Image build completed successfully!" $Green
    }
    catch {
        Write-ColorOutput "❌ Image build failed: $_" $Red
        exit 1
    }
}

function Show-Usage {
    Write-Host @"
Packer Build Script for DevCenter Custom Image

Usage: .\build-image.ps1 [OPTIONS]

Options:
  -Action <action>    Action to perform: init, validate, build, or all (default: build)
  -VarFile <file>     Variables file to use (default: variables.pkrvars.hcl)
  -Debug             Enable debug mode for Packer
  -Force             Force build even if artifacts exist
  -Help              Show this help message

Examples:
  .\build-image.ps1                                    # Build with default settings
  .\build-image.ps1 -Action validate                   # Just validate configuration
  .\build-image.ps1 -Action all                        # Init, validate, and build
  .\build-image.ps1 -VarFile custom.pkrvars.hcl       # Use custom variables file
  .\build-image.ps1 -Debug -Force                      # Debug mode with force rebuild

Prerequisites:
  1. Install Packer: https://www.packer.io/downloads
  2. Authenticate with Azure (az login or environment variables)
  3. Copy variables.pkrvars.hcl.example to variables.pkrvars.hcl and customize
  4. Ensure the Azure Compute Gallery and Image Definition exist (created by Terraform)
"@
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
    Write-ColorOutput "   Variables: $VarFile" $Yellow
    Write-ColorOutput ""
    
    # Execute based on action
    switch ($Action.ToLower()) {
        "init" {
            Test-Prerequisites
            Initialize-Packer
        }
        "validate" {
            Test-Prerequisites
            Validate-PackerConfig
        }
        "build" {
            Test-Prerequisites
            Build-Image
        }
        "all" {
            Test-Prerequisites
            Initialize-Packer
            Validate-PackerConfig
            Build-Image
        }
        default {
            Write-ColorOutput "❌ Unknown action: $Action" $Red
            Write-ColorOutput "   Valid actions: init, validate, build, all" $Yellow
            Show-Usage
            exit 1
        }
    }
    
    Write-ColorOutput ""
    Write-ColorOutput "🎉 Operation completed successfully!" $Green
}
catch {
    Write-ColorOutput "❌ Script failed: $_" $Red
    exit 1
}