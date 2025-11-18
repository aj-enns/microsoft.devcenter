<#
.SYNOPSIS
    Attach Network Connections to DevCenter
    
.DESCRIPTION
    This script attaches the network connection to DevCenter and grants
    necessary permissions to the managed identity.
    Managed by Operations Team.
    
.EXAMPLE
    .\02-attach-networks.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Attach Network Connections" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Read Terraform outputs
Write-Host "Reading Terraform state..." -ForegroundColor Yellow
$outputs = terraform output -json | ConvertFrom-Json

$devCenterName = $outputs.dev_center_name.value
$resourceGroup = $outputs.resource_group_name.value
$networkConnectionName = $outputs.network_connection_name.value

Write-Host "  DevCenter: $devCenterName" -ForegroundColor Gray
Write-Host "  Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "  Network Connection: $networkConnectionName" -ForegroundColor Gray
Write-Host ""

# Check network connection status
Write-Host "Step 1: Checking network connection..." -ForegroundColor Yellow
$ncStatus = az devcenter admin network-connection show `
    --name $networkConnectionName `
    --resource-group $resourceGroup `
    --query "{status:healthCheckStatus, details:healthCheckStatusDetails}" `
    -o json 2>&1

if ($LASTEXITCODE -eq 0) {
    $nc = $ncStatus | ConvertFrom-Json
    Write-Host "  Status: $($nc.status)" -ForegroundColor Gray
    
    if ($nc.status -ne "Passed") {
        Write-Host "  ⚠️  Network connection health check did not pass" -ForegroundColor Yellow
        Write-Host "  Details: $($nc.details)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Waiting 30 seconds for health check to complete..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30
    }
} else {
    Write-Host "  ⚠️  Could not retrieve network connection status" -ForegroundColor Yellow
}
Write-Host ""

# Attach network connection to DevCenter
Write-Host "Step 2: Attaching network to DevCenter..." -ForegroundColor Yellow
$attachedNetworks = az devcenter admin attached-network list `
    --dev-center $devCenterName `
    --resource-group $resourceGroup `
    --query "[].name" -o tsv 2>&1

if ($attachedNetworks -match $networkConnectionName) {
    Write-Host "  ✓ Network already attached" -ForegroundColor Green
} else {
    Write-Host "  Attaching network..." -ForegroundColor Cyan
    az devcenter admin attached-network create `
        --dev-center-name $devCenterName `
        --resource-group $resourceGroup `
        --name $networkConnectionName `
        --network-connection-id "/subscriptions/$($outputs.subscription_id.value)/resourceGroups/$resourceGroup/providers/Microsoft.DevCenter/networkConnections/$networkConnectionName"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Network attached successfully" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Failed to attach network" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✓ Network Configuration Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Image team can build custom images" -ForegroundColor Gray
Write-Host "  2. After images are ready, run 04-sync-pools.ps1" -ForegroundColor Gray
Write-Host "  3. (Optional) Configure Intune with 03-configure-intune.ps1" -ForegroundColor Gray
Write-Host ""
