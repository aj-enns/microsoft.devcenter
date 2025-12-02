<#
.SYNOPSIS
    Configure Intune Settings (Optional)
    
.DESCRIPTION
    This script provides guidance for configuring Intune enrollment for Dev Boxes.
    This is an optional step.
    Managed by Operations Team with Security Team.
    
.EXAMPLE
    .\03-configure-intune.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Intune Configuration (Optional)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Read Terraform outputs
Write-Host "Reading infrastructure configuration..." -ForegroundColor Yellow

# Change to infrastructure directory to read Terraform state
$originalDir = Get-Location
Set-Location (Join-Path $PSScriptRoot "..")

try {
    $outputs = terraform output -json | ConvertFrom-Json
    
    $devCenterName = $outputs.dev_center_name.value
    $resourceGroup = $outputs.resource_group_name.value
    $networkConnectionName = $outputs.network_connection_name.value
} finally {
    Set-Location $originalDir
}

Write-Host "  ✓ DevCenter: $devCenterName" -ForegroundColor Green
Write-Host "  ✓ Resource Group: $resourceGroup" -ForegroundColor Green
Write-Host ""

Write-Host "INTUNE CONFIGURATION CHECKLIST:" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. Azure AD Automatic Enrollment (Tenant-wide)" -ForegroundColor Cyan
Write-Host "   Configure in Azure Portal:" -ForegroundColor White
Write-Host "   • Navigate to: Azure Active Directory → Mobility (MDM and MAM)" -ForegroundColor Gray
Write-Host "   • Select: Microsoft Intune" -ForegroundColor Gray
Write-Host "   • Set MDM user scope: All or specific groups" -ForegroundColor Gray
Write-Host "   • Click Save" -ForegroundColor Gray
Write-Host ""

Write-Host "2. Network Connection Domain Join Type" -ForegroundColor Cyan
$ncOutput = az devcenter admin network-connection show `
    --name $networkConnectionName `
    --resource-group $resourceGroup `
    --query "{domainJoinType:domainJoinType}" -o json 2>&1

if ($LASTEXITCODE -eq 0) {
    $ncInfo = $ncOutput | ConvertFrom-Json
    Write-Host "   Current setting: $($ncInfo.domainJoinType)" -ForegroundColor White
    if ($ncInfo.domainJoinType -eq "AzureADJoin") {
        Write-Host "   ✓ Correct configuration for Intune enrollment" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Should be 'AzureADJoin' for automatic Intune enrollment" -ForegroundColor Yellow
    }
} else {
    Write-Host "   ⚠️  Could not retrieve network connection details" -ForegroundColor Yellow
    Write-Host "   Error: $ncOutput" -ForegroundColor Gray
}
Write-Host ""

Write-Host "3. License Requirements" -ForegroundColor Cyan
Write-Host "   Ensure users have:" -ForegroundColor White
Write-Host "   • Azure AD Premium P1 or P2" -ForegroundColor Gray
Write-Host "   • Microsoft Intune (or M365 E3/E5)" -ForegroundColor Gray
Write-Host ""

Write-Host "4. Intune Policies" -ForegroundColor Cyan
Write-Host "   Configure at: https://endpoint.microsoft.com" -ForegroundColor White
Write-Host "   • Compliance policies (encryption, antivirus)" -ForegroundColor Gray
Write-Host "   • Configuration profiles (settings, restrictions)" -ForegroundColor Gray
Write-Host "   • Security baselines" -ForegroundColor Gray
Write-Host "   • Windows Update rings" -ForegroundColor Gray
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✓ Configuration Guidance Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Note: Intune enrollment happens automatically when Dev Boxes" -ForegroundColor Yellow
Write-Host "are provisioned. No changes to custom images are required." -ForegroundColor Yellow
Write-Host ""

Write-Host "Resources:" -ForegroundColor Cyan
Write-Host "  • Intune docs: https://aka.ms/intunedocs" -ForegroundColor Gray
Write-Host "  • DevBox & Intune: https://aka.ms/devbox-intune" -ForegroundColor Gray
Write-Host ""
