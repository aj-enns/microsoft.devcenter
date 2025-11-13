<#
.SYNOPSIS
    Configures Intune enrollment for Dev Boxes (Optional Step 4)
    
.DESCRIPTION
    This script helps configure your Azure AD tenant and Dev Center for automatic 
    Intune enrollment of Dev Boxes. This is OPTIONAL - Dev Boxes work fine without it.
    
    Prerequisites:
    - Azure AD Premium P1/P2 license
    - Microsoft Intune licenses for users
    - Global Administrator or Intune Administrator role
    
.PARAMETER SkipAADCheck
    Skip checking Azure AD automatic enrollment configuration
    
.PARAMETER SkipDevCenterCheck
    Skip checking Dev Center configuration
    
.EXAMPLE
    .\04-configure-intune.ps1
    
.EXAMPLE
    .\04-configure-intune.ps1 -SkipAADCheck
#>

[CmdletBinding()]
param(
    [switch]$SkipAADCheck,
    [switch]$SkipDevCenterCheck
)

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Dev Box Intune Configuration (Optional Step 4)" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

# Read Terraform state
Write-Host "Reading Terraform state..." -ForegroundColor Yellow
$stateFile = "terraform.tfstate"
if (-not (Test-Path $stateFile)) {
    Write-Error "Terraform state file not found: $stateFile"
    exit 1
}

$state = Get-Content $stateFile | ConvertFrom-Json
$resourceGroup = ($state.resources | Where-Object { $_.type -eq "azurerm_resource_group" } | Select-Object -First 1).instances[0].attributes.name
$devCenterName = ($state.resources | Where-Object { $_.type -eq "azurerm_dev_center" } | Select-Object -First 1).instances[0].attributes.name
$networkConnection = $state.resources | Where-Object { $_.type -eq "azurerm_dev_center_network_connection" } | Select-Object -First 1

if ($networkConnection) {
    $networkConnectionName = $networkConnection.instances[0].attributes.name
} else {
    $networkConnectionName = "Not found"
}

Write-Host "✓ Resource Group: $resourceGroup" -ForegroundColor Green
Write-Host "✓ Dev Center: $devCenterName" -ForegroundColor Green
Write-Host "✓ Network Connection: $networkConnectionName" -ForegroundColor Green
Write-Host ""

# Check Azure AD automatic enrollment
if (-not $SkipAADCheck) {
    Write-Host "=" * 80 -ForegroundColor Yellow
    Write-Host "Step 1: Azure AD MDM Automatic Enrollment Configuration" -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Yellow
    Write-Host ""
    Write-Host "MANUAL CONFIGURATION REQUIRED:" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "1. Open Azure Portal: " -ForegroundColor White -NoNewline
    Write-Host "https://portal.azure.com" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "2. Navigate to: " -ForegroundColor White -NoNewline
    Write-Host "Azure Active Directory → Mobility (MDM and MAM)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. Select: " -ForegroundColor White -NoNewline
    Write-Host "Microsoft Intune" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "4. Configure MDM user scope:" -ForegroundColor White
    Write-Host "   • All (recommended - all users auto-enroll)" -ForegroundColor Gray
    Write-Host "   • Some (select specific Azure AD groups)" -ForegroundColor Gray
    Write-Host "   • None (disable automatic enrollment)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "5. Click " -ForegroundColor White -NoNewline
    Write-Host "'Save'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "NOTE: This is a tenant-wide setting that affects all Azure AD-joined devices." -ForegroundColor Yellow
    Write-Host ""
    
    $continue = Read-Host "Have you configured Azure AD automatic enrollment? (y/n/skip)"
    if ($continue -eq 'y') {
        Write-Host "✓ Azure AD configuration confirmed" -ForegroundColor Green
        Write-Host ""
    } elseif ($continue -eq 'skip') {
        Write-Host "⚠️  Skipping - you can configure this later" -ForegroundColor Yellow
        Write-Host "   Without this, Dev Boxes will NOT auto-enroll in Intune" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "⚠️  Configuration not confirmed" -ForegroundColor Yellow
        Write-Host "   You can run this script again after configuring Azure AD" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Check Network Connection domain join type
if (-not $SkipDevCenterCheck) {
    Write-Host "=" * 80 -ForegroundColor Yellow
    Write-Host "Step 2: Network Connection Configuration Check" -ForegroundColor Yellow
    Write-Host "=" * 80 -ForegroundColor Yellow
    Write-Host ""
    
    if ($networkConnectionName -eq "Not found") {
        Write-Host "⚠️  No network connection found in Terraform state" -ForegroundColor Yellow
        Write-Host "   This might mean the network connection is managed outside Terraform" -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host "Checking Network Connection: $networkConnectionName..." -ForegroundColor Cyan
        
        $ncCmd = "az devcenter admin network-connection show --resource-group `"$resourceGroup`" --name `"$networkConnectionName`" --query '{domainJoinType:domainJoinType}' -o json"
        
        try {
            $ncOutput = & cmd /c $ncCmd '2>&1'
            if ($LASTEXITCODE -eq 0) {
                $ncInfo = $ncOutput | ConvertFrom-Json
                
                Write-Host "  Domain Join Type: " -ForegroundColor White -NoNewline
                Write-Host "$($ncInfo.domainJoinType)" -ForegroundColor Cyan
                Write-Host ""
                
                if ($ncInfo.domainJoinType -eq "AzureADJoin") {
                    Write-Host "✓ Network Connection is configured for Azure AD Join" -ForegroundColor Green
                    Write-Host "  This is the correct configuration for automatic Intune enrollment!" -ForegroundColor Green
                    Write-Host ""
                } else {
                    Write-Host "⚠️  Network Connection is using: $($ncInfo.domainJoinType)" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "For automatic Intune enrollment, the domain join type should be 'AzureADJoin'." -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "To change this:" -ForegroundColor White
                    Write-Host "  1. Update your Terraform configuration in the vnet module" -ForegroundColor Gray
                    Write-Host "  2. Set: domain_join_type = `"AzureADJoin`"" -ForegroundColor Gray
                    Write-Host "  3. Run: terraform apply" -ForegroundColor Gray
                    Write-Host ""
                    Write-Host "Note: Changing this requires recreating the network connection and" -ForegroundColor Yellow
                    Write-Host "      any existing Dev Box pools using this connection." -ForegroundColor Yellow
                    Write-Host ""
                }
            } else {
                Write-Host "⚠️  Could not retrieve network connection info" -ForegroundColor Yellow
                Write-Host "   Error output:" -ForegroundColor Red
                $ncOutput | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
                Write-Host ""
            }
        } catch {
            Write-Host "⚠️  Error checking network connection" -ForegroundColor Yellow
            Write-Host "   Error: $_" -ForegroundColor Red
            Write-Host ""
        }
    }
}

# Check Dev Center provisioning settings
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host "Step 3: Dev Center Provisioning Settings Check" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host ""

$dcCmd = "az devcenter admin devcenter show --name `"$devCenterName`" --resource-group `"$resourceGroup`" --query '{installAzureMonitorAgent:devBoxProvisioningSettings.installAzureMonitorAgentEnableStatus}' -o json"

try {
    $dcOutput = & cmd /c $dcCmd '2>&1'
    if ($LASTEXITCODE -eq 0) {
        $dcInfo = $dcOutput | ConvertFrom-Json
        
        Write-Host "Azure Monitor Agent Status: " -ForegroundColor White -NoNewline
        
        if ($dcInfo.installAzureMonitorAgent -eq "Enabled") {
            Write-Host "Enabled" -ForegroundColor Green
            Write-Host "✓ Azure Monitor Agent is enabled (recommended for Intune)" -ForegroundColor Green
            Write-Host ""
        } else {
            Write-Host "$($dcInfo.installAzureMonitorAgent)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "⚠️  Azure Monitor Agent is not enabled" -ForegroundColor Yellow
            Write-Host "   While not required for Intune, this is recommended for:" -ForegroundColor Yellow
            Write-Host "   • Better monitoring and diagnostics" -ForegroundColor Gray
            Write-Host "   • Integration with Azure Monitor" -ForegroundColor Gray
            Write-Host "   • Compliance reporting" -ForegroundColor Gray
            Write-Host ""
            Write-Host "To enable via Azure Portal:" -ForegroundColor White
            Write-Host "  1. Go to your Dev Center: $devCenterName" -ForegroundColor Gray
            Write-Host "  2. Navigate to Settings → Provisioning" -ForegroundColor Gray
            Write-Host "  3. Enable 'Install Azure Monitor Agent'" -ForegroundColor Gray
            Write-Host ""
        }
    } else {
        Write-Host "⚠️  Could not retrieve Dev Center provisioning settings" -ForegroundColor Yellow
        Write-Host "   This is not critical for Intune enrollment" -ForegroundColor Yellow
        Write-Host ""
    }
} catch {
    Write-Host "⚠️  Error checking Dev Center settings" -ForegroundColor Yellow
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host ""
}

# License check reminder
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host "Step 4: License Requirements" -ForegroundColor Yellow
Write-Host "=" * 80 -ForegroundColor Yellow
Write-Host ""
Write-Host "Ensure users have the following licenses assigned:" -ForegroundColor White
Write-Host ""
Write-Host "Required:" -ForegroundColor Cyan
Write-Host "  [ ] Azure AD Premium P1 or P2" -ForegroundColor White
Write-Host "  [ ] Microsoft Intune (or Microsoft 365 E3/E5)" -ForegroundColor White
Write-Host ""
Write-Host "Verify in Azure Portal:" -ForegroundColor White
Write-Host "  Azure Active Directory → Users → [Select User] → Licenses" -ForegroundColor Gray
Write-Host ""

# Summary and next steps
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Configuration Summary & Next Steps" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""

Write-Host "INTUNE ENROLLMENT CHECKLIST:" -ForegroundColor Yellow
Write-Host "  [ ] Azure AD Premium P1/P2 licenses assigned to users" -ForegroundColor White
Write-Host "  [ ] Microsoft Intune licenses assigned to users" -ForegroundColor White
Write-Host "  [ ] Azure AD Automatic MDM Enrollment configured" -ForegroundColor White
Write-Host "  [ ] Network Connection uses 'AzureADJoin'" -ForegroundColor White
Write-Host "  [ ] Azure Monitor Agent enabled (optional but recommended)" -ForegroundColor White
Write-Host ""

Write-Host "TESTING INTUNE ENROLLMENT:" -ForegroundColor Yellow
Write-Host "1. Provision a Dev Box from the Dev Portal" -ForegroundColor White
Write-Host "2. Connect to the Dev Box via RDP" -ForegroundColor White
Write-Host "3. Open PowerShell and run:" -ForegroundColor White
Write-Host ""
Write-Host "   dsregcmd /status" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Verify the output shows:" -ForegroundColor White
Write-Host "   AzureAdJoined : YES" -ForegroundColor Gray
Write-Host "   MDMUrl : https://enrollment.manage.microsoft.com/..." -ForegroundColor Gray
Write-Host ""

Write-Host "CONFIGURING INTUNE POLICIES:" -ForegroundColor Yellow
Write-Host "1. Open Microsoft Endpoint Manager: " -ForegroundColor White -NoNewline
Write-Host "https://endpoint.microsoft.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Configure policies for Dev Boxes:" -ForegroundColor White
Write-Host "   • Devices → Compliance policies (encryption, antivirus, etc.)" -ForegroundColor Gray
Write-Host "   • Devices → Configuration profiles (settings, restrictions)" -ForegroundColor Gray
Write-Host "   • Endpoint security → Security baselines" -ForegroundColor Gray
Write-Host "   • Devices → Windows updates → Update rings" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Assign policies to:" -ForegroundColor White
Write-Host "   • All devices" -ForegroundColor Gray
Write-Host "   • Specific device groups" -ForegroundColor Gray
Write-Host "   • User groups" -ForegroundColor Gray
Write-Host ""

Write-Host "ADDITIONAL RESOURCES:" -ForegroundColor Yellow
Write-Host "  • Intune documentation: https://aka.ms/intunedocs" -ForegroundColor Cyan
Write-Host "  • Dev Box & Intune: https://aka.ms/devbox-intune" -ForegroundColor Cyan
Write-Host ""

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "✓ Step 4 Complete - Intune configuration reviewed" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: Intune enrollment happens automatically when Dev Boxes are provisioned." -ForegroundColor Yellow
Write-Host "      No changes to your custom images are required!" -ForegroundColor Yellow
Write-Host ""
