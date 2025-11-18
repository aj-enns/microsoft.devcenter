<#
.SYNOPSIS
    Sync DevBox Pools from Image Definitions
    
.DESCRIPTION
    This script reads the devbox-definitions.json from the images repository
    and creates/updates DevBox pools accordingly.
    
    This ensures that any new definitions added by development teams
    automatically get pools created for them.
    
    Managed by Operations Team - triggered when images are updated.
    
.PARAMETER DefinitionsPath
    Path to the devbox-definitions.json file
    Default: Looks in images folder or accepts URL
    
.EXAMPLE
    .\04-sync-pools.ps1
    
.EXAMPLE
    .\04-sync-pools.ps1 -DefinitionsPath "..\..\images\definitions\devbox-definitions.json"
#>

[CmdletBinding()]
param(
    [string]$DefinitionsPath = "../../images/definitions/devbox-definitions.json"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Sync DevBox Pools from Definitions" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Read Terraform outputs
Write-Host "Step 1: Reading infrastructure configuration..." -ForegroundColor Yellow

# Change to infrastructure directory to read Terraform state
$originalDir = Get-Location
Set-Location (Join-Path $PSScriptRoot "..")

try {
    $outputs = terraform output -json | ConvertFrom-Json
    
    $devCenterName = $outputs.dev_center_name.value
    $projectName = $outputs.project_name.value
    $resourceGroup = $outputs.resource_group_name.value
    $location = $outputs.location.value
    $subscriptionId = $outputs.subscription_id.value
} finally {
    Set-Location $originalDir
}

Write-Host "  ✓ DevCenter: $devCenterName" -ForegroundColor Green
Write-Host "  ✓ Project: $projectName" -ForegroundColor Green
Write-Host "  ✓ Resource Group: $resourceGroup" -ForegroundColor Green
Write-Host ""

# Read definitions file
Write-Host "Step 2: Reading DevBox definitions..." -ForegroundColor Yellow
if (-not (Test-Path $DefinitionsPath)) {
    Write-Host "  ❌ Definitions file not found: $DefinitionsPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected location: images/definitions/devbox-definitions.json" -ForegroundColor Yellow
    Write-Host "Make sure image team has created this file." -ForegroundColor Yellow
    exit 1
}

$definitions = Get-Content $DefinitionsPath | ConvertFrom-Json
Write-Host "  ✓ Found $($definitions.definitions.Count) definitions" -ForegroundColor Green
Write-Host "  ✓ Found $($definitions.pools.Count) pool configurations" -ForegroundColor Green
Write-Host ""

# Get existing definitions in DevCenter
Write-Host "Step 3: Checking existing DevBox definitions in DevCenter..." -ForegroundColor Yellow
$existingDefinitions = az devcenter admin devbox-definition list `
    --dev-center-name $devCenterName `
    --resource-group $resourceGroup `
    --query "[].name" -o tsv 2>&1

$existingDefArray = if ($existingDefinitions) { $existingDefinitions -split "`n" } else { @() }
Write-Host "  ✓ Found $($existingDefArray.Count) existing definitions in DevCenter" -ForegroundColor Green
Write-Host ""

# Create or update pools
Write-Host "Step 4: Creating/updating DevBox pools..." -ForegroundColor Yellow
Write-Host ""

foreach ($pool in $definitions.pools) {
    $poolName = $pool.name
    $definitionName = $pool.definitionName
    
    Write-Host "  Processing pool: $poolName" -ForegroundColor Cyan
    
    # Check if definition exists
    if ($definitionName -notin $existingDefArray) {
        Write-Host "    ⚠️  Definition '$definitionName' not found in DevCenter" -ForegroundColor Yellow
        Write-Host "    Skipping pool creation. Image team should build this image first." -ForegroundColor Yellow
        Write-Host ""
        continue
    }
    
    # Check if pool already exists
    $poolExists = az devcenter admin pool show `
        --name $poolName `
        --project $projectName `
        --resource-group $resourceGroup `
        --query "name" -o tsv 2>$null
    
    if ($poolExists) {
        Write-Host "    ✓ Pool already exists" -ForegroundColor Green
        Write-Host ""
        continue
    }
    
    # Create pool
    Write-Host "    Creating new pool..." -ForegroundColor Cyan
    
    $createCmd = "az devcenter admin pool create " +
                 "--name `"$poolName`" " +
                 "--project `"$projectName`" " +
                 "--resource-group `"$resourceGroup`" " +
                 "--devbox-definition-name `"$definitionName`" " +
                 "--network-connection-name `"$($outputs.network_connection_name.value)`" " +
                 "--local-administrator `"$($pool.administrator)`" " +
                 "--location `"$location`""
    
    # Add stop schedule if configured
    if ($pool.schedule) {
        $createCmd += " --stop-on-disconnect status=`"Enabled`" grace-period-minutes=60"
    }
    
    Write-Host "    Command: $createCmd" -ForegroundColor DarkGray
    
    $output = & cmd /c $createCmd '2>&1'
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Pool created successfully" -ForegroundColor Green
    } else {
        Write-Host "    ✗ Failed to create pool" -ForegroundColor Red
        Write-Host "    Output: $output" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✓ Pool Synchronization Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  • Definitions checked: $($definitions.definitions.Count)" -ForegroundColor Gray
Write-Host "  • Pools configured: $($definitions.pools.Count)" -ForegroundColor Gray
Write-Host ""

Write-Host "Dev Portal: https://devportal.microsoft.com" -ForegroundColor Yellow
Write-Host "Users can now provision Dev Boxes from the available pools." -ForegroundColor Gray
Write-Host ""
