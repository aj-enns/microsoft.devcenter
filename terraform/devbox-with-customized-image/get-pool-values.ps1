#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Get values needed to create DevCenter pools
.DESCRIPTION
    This script extracts all necessary values from Terraform state and Azure
    to create DevCenter pools manually.
#>

$ErrorActionPreference = "Stop"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White",
        [switch]$NoNewline
    )
    if ($NoNewline) {
        Write-Host $Message -ForegroundColor $Color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}

Write-ColorOutput "`n📋 DevCenter Pool Configuration Values" "Cyan"
Write-ColorOutput "========================================`n" "Cyan"

# Check if we're in the right directory
if (-not (Test-Path "terraform.tfstate")) {
    Write-ColorOutput "❌ terraform.tfstate not found. Please run this from the Terraform directory." "Red"
    exit 1
}

try {
    # Read Terraform state
    $state = Get-Content "terraform.tfstate" | ConvertFrom-Json
    
    # Extract values from Terraform outputs
    $outputs = $state.outputs
    
    # Get resource group name
    $resourceGroup = $state.resources | 
        Where-Object { $_.type -eq "azurerm_resource_group" } | 
        Select-Object -First 1 -ExpandProperty instances | 
        Select-Object -First 1 -ExpandProperty attributes | 
        Select-Object -ExpandProperty name
    
    # Get DevCenter name
    $devCenterName = $state.resources | 
        Where-Object { $_.type -eq "azurerm_dev_center" -and $_.module -like "*devcenter*" } | 
        Select-Object -First 1 -ExpandProperty instances | 
        Select-Object -First 1 -ExpandProperty attributes | 
        Select-Object -ExpandProperty name
    
    # Get Project name
    $projectName = $state.resources | 
        Where-Object { $_.type -eq "azurerm_dev_center_project" } | 
        Select-Object -First 1 -ExpandProperty instances | 
        Select-Object -First 1 -ExpandProperty attributes | 
        Select-Object -ExpandProperty name
    
    # Get Network Connection name
    $networkConnectionName = $state.resources | 
        Where-Object { $_.type -eq "azurerm_dev_center_network_connection" } | 
        Select-Object -First 1 -ExpandProperty instances | 
        Select-Object -First 1 -ExpandProperty attributes | 
        Select-Object -ExpandProperty name
    
    # Get Network Connection ID
    $networkConnectionId = $state.resources | 
        Where-Object { $_.type -eq "azurerm_dev_center_network_connection" } | 
        Select-Object -First 1 -ExpandProperty instances | 
        Select-Object -First 1 -ExpandProperty attributes | 
        Select-Object -ExpandProperty id
    
    # Get Location
    $location = $state.resources | 
        Where-Object { $_.type -eq "azurerm_resource_group" } | 
        Select-Object -First 1 -ExpandProperty instances | 
        Select-Object -First 1 -ExpandProperty attributes | 
        Select-Object -ExpandProperty location
    
    # Get Subscription ID
    $subscriptionId = $state.resources | 
        Where-Object { $_.type -eq "azurerm_resource_group" } | 
        Select-Object -First 1 -ExpandProperty instances | 
        Select-Object -First 1 -ExpandProperty attributes | 
        Select-Object -ExpandProperty id | 
        ForEach-Object { ($_ -split '/')[2] }
    
    # Get DevBox Definitions
    $definitions = $state.resources | 
        Where-Object { $_.type -eq "azurerm_dev_center_dev_box_definition" } | 
        ForEach-Object { 
            $_.instances | ForEach-Object { 
                $_.attributes | Select-Object name, sku_name 
            }
        }
    
    # Read DevCenter settings for pool configuration
    $devCenterSettings = Get-Content "devcenter-settings.json" | ConvertFrom-Json
    
    # Display values
    Write-ColorOutput "🔧 Core Configuration:" "Yellow"
    Write-ColorOutput "  Resource Group:       " "Gray" -NoNewline
    Write-ColorOutput $resourceGroup "White"
    Write-ColorOutput "  DevCenter Name:       " "Gray" -NoNewline
    Write-ColorOutput $devCenterName "White"
    Write-ColorOutput "  Project Name:         " "Gray" -NoNewline
    Write-ColorOutput $projectName "White"
    Write-ColorOutput "  Location:             " "Gray" -NoNewline
    Write-ColorOutput $location "White"
    Write-ColorOutput "  Subscription ID:      " "Gray" -NoNewline
    Write-ColorOutput $subscriptionId "White"
    
    Write-ColorOutput "`n🌐 Network Configuration:" "Yellow"
    Write-ColorOutput "  Connection Name:      " "Gray" -NoNewline
    Write-ColorOutput $networkConnectionName "White"
    Write-ColorOutput "  Connection ID:        " "Gray" -NoNewline
    Write-ColorOutput $networkConnectionId "Cyan"
    
    Write-ColorOutput "`n📦 DevBox Definitions:" "Yellow"
    foreach ($def in $definitions) {
        Write-ColorOutput "  • $($def.name)" "White"
        Write-ColorOutput "    SKU: $($def.sku_name)" "Gray"
    }
    
    Write-ColorOutput "`n🏊 Pool Configuration from devcenter-settings.json:" "Yellow"
    foreach ($pool in $devCenterSettings.customizedImagePools) {
        Write-ColorOutput "  • Pool: $($pool.name)" "White"
        Write-ColorOutput "    Definition: $($pool.definition)" "Gray"
        Write-ColorOutput "    Administrator: $($pool.administrator)" "Gray"
    }
    
    # Generate commands
    Write-ColorOutput "`n🚀 Commands to Create Pools:" "Green"
    Write-ColorOutput "================================`n" "Green"
    
    # 1. Attach network command
    Write-ColorOutput "# Step 1: Attach Network Connection to DevCenter" "Yellow"
    $attachNetworkCmd = @"
az devcenter admin attached-network create ``
    --name "$networkConnectionName" ``
    --dev-center "$devCenterName" ``
    --resource-group "$resourceGroup" ``
    --network-connection-id "$networkConnectionId"
"@
    Write-Host $attachNetworkCmd -ForegroundColor Cyan
    
    Write-ColorOutput "`n# Step 2: Create Dev Box Pools" "Yellow"
    
    # 2. Create pool commands for each pool
    foreach ($pool in $devCenterSettings.customizedImagePools) {
        Write-ColorOutput "`n# Create pool: $($pool.name)" "Yellow"
        $createPoolCmd = @"
az devcenter admin pool create ``
    --name "$($pool.name)" ``
    --project-name "$projectName" ``
    --resource-group "$resourceGroup" ``
    --location "$location" ``
    --devbox-definition-name "$($pool.definition)" ``
    --network-connection-name "$networkConnectionName" ``
    --local-administrator "$($pool.administrator)"
"@
        Write-Host $createPoolCmd -ForegroundColor Cyan
    }
    
    # Create a script file with all commands
    Write-ColorOutput "`n💾 Saving commands to create-pools.ps1..." "Yellow"
    
    $scriptContent = @"
#!/usr/bin/env pwsh
# Auto-generated script to create DevCenter pools
# Generated on: $(Get-Date)

`$ErrorActionPreference = "Stop"

Write-Host "🚀 Creating DevCenter Pools" -ForegroundColor Cyan
Write-Host "===========================`n" -ForegroundColor Cyan

# Step 1: Attach Network Connection
Write-Host "📡 Attaching network connection..." -ForegroundColor Yellow
az devcenter admin attached-network create ``
    --name "$networkConnectionName" ``
    --dev-center "$devCenterName" ``
    --resource-group "$resourceGroup" ``
    --network-connection-id "$networkConnectionId" 2>`$null

if (`$LASTEXITCODE -eq 0 -or `$LASTEXITCODE -eq 1) {
    Write-Host "✅ Network attached (or already attached)`n" -ForegroundColor Green
} else {
    Write-Host "⚠️  Warning: Network attachment returned exit code `$LASTEXITCODE`n" -ForegroundColor Yellow
}

# Step 2: Wait for Network Connection Health Check
Write-Host "🔍 Checking network connection health status..." -ForegroundColor Yellow
Write-Host "   Note: The network health check can take 5-10 minutes to pass." -ForegroundColor Gray
Write-Host "   Common reasons for failure:" -ForegroundColor Gray
Write-Host "   - Network connection not yet validated by Azure" -ForegroundColor Gray
Write-Host "   - Subnet configuration issues" -ForegroundColor Gray
Write-Host "   - DNS or domain join settings`n" -ForegroundColor Gray

`$maxAttempts = 20
`$attemptCount = 0
`$healthCheckPassed = `$false

while (`$attemptCount -lt `$maxAttempts -and -not `$healthCheckPassed) {
    `$attemptCount++
    Write-Host "   Attempt `$attemptCount/`$maxAttempts..." -ForegroundColor Cyan
    
    `$networkStatus = az devcenter admin attached-network show ``
        --name "$networkConnectionName" ``
        --dev-center "$devCenterName" ``
        --resource-group "$resourceGroup" 2>`$null | ConvertFrom-Json
    
    if (`$networkStatus.healthCheckStatus -eq "Passed") {
        `$healthCheckPassed = `$true
        Write-Host "✅ Network health check passed!`n" -ForegroundColor Green
        break
    } elseif (`$networkStatus.healthCheckStatus -eq "Failed") {
        Write-Host "   ⚠️  Health check status: Failed (attempt `$attemptCount/`$maxAttempts)" -ForegroundColor Yellow
        if (`$attemptCount -lt `$maxAttempts) {
            Write-Host "   Waiting 30 seconds before retry..." -ForegroundColor Gray
            Start-Sleep -Seconds 30
        }
    } else {
        Write-Host "   ℹ️  Health check status: `$(`$networkStatus.healthCheckStatus) (attempt `$attemptCount/`$maxAttempts)" -ForegroundColor Gray
        if (`$attemptCount -lt `$maxAttempts) {
            Write-Host "   Waiting 30 seconds before retry..." -ForegroundColor Gray
            Start-Sleep -Seconds 30
        }
    }
}

if (-not `$healthCheckPassed) {
    Write-Host "`n⚠️  WARNING: Network health check has not passed after `$(`$maxAttempts * 30) seconds." -ForegroundColor Yellow
    Write-Host "   This usually indicates a network configuration issue." -ForegroundColor Yellow
    Write-Host "`n   Troubleshooting steps:" -ForegroundColor Cyan
    Write-Host "   1. Check the network connection in Azure Portal:" -ForegroundColor White
    Write-Host "      https://portal.azure.com/#view/Microsoft_Azure_DevCenter/NetworkConnectionMenuBlade/~/overview/resourceId/%2Fsubscriptions%2F$subscriptionId%2FresourceGroups%2F$resourceGroup%2Fproviders%2FMicrosoft.DevCenter%2FnetworkConnections%2F$networkConnectionName" -ForegroundColor Gray
    Write-Host "   2. Verify the subnet has proper DNS and connectivity" -ForegroundColor White
    Write-Host "   3. Ensure no network policies are blocking DevCenter`n" -ForegroundColor White
    
    `$continue = Read-Host "Do you want to attempt creating pools anyway? (y/N)"
    if (`$continue -ne "y" -and `$continue -ne "Y") {
        Write-Host "`n❌ Exiting. Fix network issues and run this script again.`n" -ForegroundColor Red
        exit 1
    }
    Write-Host "`n⚠️  Proceeding despite health check failure...`n" -ForegroundColor Yellow
}

"@
    
    foreach ($pool in $devCenterSettings.customizedImagePools) {
        $scriptContent += @"

# Create pool: $($pool.name)
Write-Host "🏊 Creating pool: $($pool.name)..." -ForegroundColor Yellow
az devcenter admin pool create ``
    --name "$($pool.name)" ``
    --project-name "$projectName" ``
    --resource-group "$resourceGroup" ``
    --location "$location" ``
    --devbox-definition-name "$($pool.definition)" ``
    --network-connection-name "$networkConnectionName" ``
    --local-administrator "$($pool.administrator)"

if (`$LASTEXITCODE -eq 0) {
    Write-Host "✅ Pool '$($pool.name)' created successfully`n" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to create pool '$($pool.name)'`n" -ForegroundColor Red
}

"@
    }
    
    $scriptContent += @"

Write-Host "`n🎉 Pool creation process complete!" -ForegroundColor Green
Write-Host "`n📋 Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Check pool status in Azure Portal or run:" -ForegroundColor White
Write-Host "     az devcenter admin pool list --project-name $projectName --resource-group $resourceGroup" -ForegroundColor Gray
Write-Host "  2. If pools failed, check network connection health:" -ForegroundColor White
Write-Host "     az devcenter admin network-connection show --name $networkConnectionName --resource-group $resourceGroup" -ForegroundColor Gray
Write-Host "  3. Once pools are provisioned, go to https://devbox.microsoft.com" -ForegroundColor White
Write-Host "  4. Sign in and create your Dev Box`n" -ForegroundColor White
"@
    
    Set-Content -Path "create-pools.ps1" -Value $scriptContent
    
    Write-ColorOutput "✅ Commands saved to create-pools.ps1" "Green"
    Write-ColorOutput "`nYou can now run: .\create-pools.ps1" "Cyan"
    
} catch {
    Write-ColorOutput "`n❌ Error reading Terraform state: $_" "Red"
    Write-ColorOutput "`nMake sure you have run 'terraform apply' successfully." "Yellow"
    exit 1
}

Write-ColorOutput "`n✨ Done!`n" "Green"
exit 0