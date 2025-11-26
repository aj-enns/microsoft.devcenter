<#
.SYNOPSIS
    Deploy DevCenter Infrastructure
    
.DESCRIPTION
    This script deploys the core DevCenter infrastructure using Terraform.
    Managed by Operations Team.
    
    Steps:
    1. Initialize Terraform
    2. Plan infrastructure changes
    3. Apply infrastructure (with user confirmation)
    
.PARAMETER AutoApprove
    Skip confirmation prompts for Terraform apply
    
.EXAMPLE
    .\01-deploy-infrastructure.ps1
    
.EXAMPLE
    .\01-deploy-infrastructure.ps1 -AutoApprove
#>

[CmdletBinding()]
param(
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DevCenter Infrastructure Deployment" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "❌ terraform.tfvars not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please create terraform.tfvars file with your configuration." -ForegroundColor Yellow
    Write-Host "You can copy from terraform.tfvars.example:" -ForegroundColor Yellow
    Write-Host "  cp terraform.tfvars.example terraform.tfvars" -ForegroundColor Gray
    Write-Host ""
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

# Initialize Terraform
Write-Host "Step 2: Initializing Terraform..." -ForegroundColor Yellow
terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Terraform init failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Terraform initialized" -ForegroundColor Green
Write-Host ""

# Terraform Plan
Write-Host "Step 3: Planning infrastructure changes..." -ForegroundColor Yellow
terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Terraform plan failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Plan created successfully" -ForegroundColor Green
Write-Host ""

# Terraform Apply
Write-Host "Step 4: Applying infrastructure..." -ForegroundColor Yellow
if ($AutoApprove) {
    terraform apply -auto-approve tfplan
} else {
    Write-Host ""
    Write-Host "Review the plan above. Do you want to apply these changes?" -ForegroundColor Cyan
    $confirm = Read-Host "Type 'yes' to continue"
    
    if ($confirm -eq "yes") {
        terraform apply tfplan
    } else {
        Write-Host "  ⚠️  Deployment cancelled" -ForegroundColor Yellow
        exit 0
    }
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Terraform apply failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✓ Infrastructure Deployment Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

# Display outputs
Write-Host "Infrastructure Details:" -ForegroundColor Cyan
terraform output
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Image team can now build custom images (see images/ folder)" -ForegroundColor Gray
Write-Host "  2. Run 02-attach-networks.ps1 to attach network connections" -ForegroundColor Gray
Write-Host "  3. After images are built, run 04-sync-pools.ps1" -ForegroundColor Gray
Write-Host ""
