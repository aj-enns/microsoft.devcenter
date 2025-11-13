# Create DevBox Definitions
# This script creates DevBox definitions from the Terraform state and devcenter-settings.json

Write-Host "Reading Terraform state..." -ForegroundColor Cyan
$stateFile = "terraform.tfstate"
if (-not (Test-Path $stateFile)) {
    Write-Error "Terraform state file not found: $stateFile"
    exit 1
}

$state = Get-Content $stateFile | ConvertFrom-Json

# Extract values from Terraform state
$resourceGroup = ($state.resources | Where-Object { $_.type -eq "azurerm_resource_group" } | Select-Object -First 1).instances[0].attributes.name
$devCenterName = ($state.resources | Where-Object { $_.type -eq "azurerm_dev_center" } | Select-Object -First 1).instances[0].attributes.name
$location = ($state.resources | Where-Object { $_.type -eq "azurerm_dev_center" } | Select-Object -First 1).instances[0].attributes.location

Write-Host "Resource Group: $resourceGroup" -ForegroundColor Green
Write-Host "DevCenter: $devCenterName" -ForegroundColor Green
Write-Host "Location: $location" -ForegroundColor Green

# Get DevCenter gallery name
$devCenterGallery = ($state.resources | Where-Object { $_.type -eq "azurerm_dev_center_gallery" } | Select-Object -First 1).instances[0].attributes.name

# Build DevCenter image references
$galleryImages = $state.resources | Where-Object { $_.type -eq "azurerm_shared_image" }
$imageMap = @{}
foreach ($img in $galleryImages) {
    foreach ($instance in $img.instances) {
        $imgName = $instance.attributes.name
        # Use DevCenter gallery path instead of compute gallery path
        $imgId = "/subscriptions/$($state.resources[0].instances[0].attributes.subscription_id)/resourceGroups/$resourceGroup/providers/Microsoft.DevCenter/devCenters/$devCenterName/galleries/$devCenterGallery/images/$imgName"
        $imageMap[$imgName] = $imgId
    }
}

Write-Host "`nAvailable Images:" -ForegroundColor Cyan
$imageMap.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor Gray
}

# Read devcenter-settings.json
Write-Host "`nReading DevCenter settings..." -ForegroundColor Cyan
$settingsFile = "devcenter-settings.json"
if (-not (Test-Path $settingsFile)) {
    Write-Error "Settings file not found: $settingsFile"
    exit 1
}

$devCenterSettings = Get-Content $settingsFile | ConvertFrom-Json

# Compute SKU mapping
$computeMap = @{
    "8c-32gb" = "general_i_8c32gb256ssd_v2"
    "16c-64gb" = "general_i_16c64gb512ssd_v2"
    "32c-128gb" = "general_i_32c128gb1024ssd_v2"
}

Write-Host "`nCreating DevBox Definitions..." -ForegroundColor Yellow

foreach ($def in $devCenterSettings.customizedImageDevboxdefinitions) {
    $defName = $def.name
    $imageType = $def.imageType
    $compute = $def.compute
    $storage = $def.storage
    
    # Get the image ID
    if (-not $imageMap.ContainsKey($imageType)) {
        Write-Error "Image type '$imageType' not found in gallery"
        continue
    }
    $imageId = $imageMap[$imageType]
    
    # Get the SKU
    if (-not $computeMap.ContainsKey($compute)) {
        Write-Error "Compute size '$compute' not mapped"
        continue
    }
    $skuName = $computeMap[$compute]
    
    # Map storage to os-storage-type - use proper format
    # Format should be: ssd_256gb, ssd_512gb, ssd_1024gb, ssd_2048gb
    $storageType = "ssd_$storage"
    
    Write-Host "`n  Creating definition: $defName" -ForegroundColor Cyan
    Write-Host "    Image: $imageType" -ForegroundColor Gray
    Write-Host "    SKU: $skuName" -ForegroundColor Gray
    Write-Host "    Storage: $storageType" -ForegroundColor Gray
    
    $cmd = "az devcenter admin devbox-definition create " +
           "--dev-center-name `"$devCenterName`" " +
           "--resource-group `"$resourceGroup`" " +
           "--devbox-definition-name `"$defName`" " +
           "--image-reference id=`"$imageId`" " +
           "--sku name=`"$skuName`" " +
           "--os-storage-type `"$storageType`" " +
           "--location `"$location`""
    
    Write-Host "    Command: $cmd" -ForegroundColor DarkGray
    
    $output = & cmd /c $cmd '2>&1'
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Created successfully" -ForegroundColor Green
    } else {
        Write-Host "    ✗ Failed to create (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
        Write-Host "    Output:" -ForegroundColor Yellow
        $output | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
    }
}

Write-Host "`n✓ DevBox definitions creation complete" -ForegroundColor Green

# Update project to allow dev box creation
Write-Host "`n📝 Updating project settings..." -ForegroundColor Yellow

$projectName = ($state.resources | Where-Object { $_.type -eq "azurerm_dev_center_project" } | Select-Object -First 1).instances[0].attributes.name

# Try to get value from tfvars, otherwise use default
$maxDevBoxesPerUser = 10  # Default limit
if (Test-Path "terraform.tfvars") {
    $tfvarsContent = Get-Content "terraform.tfvars" -Raw
    if ($tfvarsContent -match 'max_dev_boxes_per_user\s*=\s*(\d+)') {
        $maxDevBoxesPerUser = [int]$Matches[1]
    }
}

Write-Host "  Setting max dev boxes per user to $maxDevBoxesPerUser..." -ForegroundColor Cyan

$updateCmd = "az devcenter admin project update " +
           "--name `"$projectName`" " +
           "--resource-group `"$resourceGroup`" " +
           "--max-dev-boxes-per-user $maxDevBoxesPerUser"

$output = & cmd /c $updateCmd '2>&1'
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Project updated successfully" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Warning: Failed to update project settings" -ForegroundColor Yellow
    Write-Host "  You can update manually with:" -ForegroundColor Gray
    Write-Host "    az devcenter admin project update --name $projectName --resource-group $resourceGroup --max-dev-boxes-per-user 10" -ForegroundColor Gray
}

Write-Host "`nYou can now run 03-create-pools.ps1 to create the pools" -ForegroundColor Yellow
