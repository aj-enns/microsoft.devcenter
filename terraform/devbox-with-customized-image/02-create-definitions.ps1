# Create DevBox Definitions
# This script:
# 1. Creates Azure Compute Gallery if it doesn't exist
# 2. Creates image definitions in the gallery
# 3. Grants DevCenter managed identity access to the gallery
# 4. Attaches the gallery to DevCenter
# 5. Creates DevBox definitions from devcenter-settings.json
# 6. Updates project settings
# 7. Auto-generates Packer variable files with correct values

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DevBox Definitions Setup Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

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

Write-Host "  Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "  DevCenter: $devCenterName" -ForegroundColor Gray
Write-Host "  Location: $location" -ForegroundColor Gray
Write-Host ""

# Get subscription ID
$subscriptionId = az account show --query id -o tsv

# Generate gallery name (same pattern as Terraform used to use)
$randomToken = ($state.resources | Where-Object { $_.type -eq "random_string" } | Select-Object -First 1).instances[0].attributes.result
$galleryName = "gal$randomToken"

Write-Host "Step 1: Check/Create Azure Compute Gallery" -ForegroundColor Yellow
Write-Host "  Gallery Name: $galleryName" -ForegroundColor Gray

# Check if gallery exists
$galleryExists = az sig show --gallery-name $galleryName --resource-group $resourceGroup 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Gallery already exists" -ForegroundColor Green
} else {
    Write-Host "  Creating gallery..." -ForegroundColor Cyan
    az sig create --gallery-name $galleryName --resource-group $resourceGroup --location $location
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Gallery created successfully" -ForegroundColor Green
    } else {
        Write-Error "Failed to create gallery"
        exit 1
    }
}

Write-Host ""
Write-Host "Step 2: Create Image Definitions" -ForegroundColor Yellow

# Image definitions to create
$imageDefinitions = @(
    @{
        name = "VSCodeImage"
        offer = "visualstudio-ent-cpc"
        publisher = "MicrosoftWindowsDesktop"
        sku = "win11-22h2-ent-cpc-m365-vscode"
    },
    @{
        name = "VisualStudioImage"
        offer = "visualstudioplustools"
        publisher = "MicrosoftVisualStudio"
        sku = "vs-2022-ent-general-win11-m365-gen2"
    },
    @{
        name = "IntelliJDevImage"
        offer = "windows-ent-cpc"
        publisher = "MicrosoftWindowsDesktop"
        sku = "win11-22h2-ent-cpc-m365-intellij"
    }
)

$imageMap = @{}
foreach ($imgDef in $imageDefinitions) {
    $imgName = $imgDef.name
    Write-Host "  Checking image definition: $imgName" -ForegroundColor Cyan
    
    $imgExists = az sig image-definition show --gallery-name $galleryName --gallery-image-definition $imgName --resource-group $resourceGroup 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Image definition already exists" -ForegroundColor Green
    } else {
        Write-Host "    Creating image definition..." -ForegroundColor Cyan
        az sig image-definition create `
            --gallery-name $galleryName `
            --gallery-image-definition $imgName `
            --resource-group $resourceGroup `
            --location $location `
            --os-type Windows `
            --os-state Generalized `
            --hyper-v-generation V2 `
            --features SecurityType=TrustedLaunch `
            --publisher $($imgDef.publisher) `
            --offer $($imgDef.offer) `
            --sku $($imgDef.sku)
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    ✓ Image definition created successfully" -ForegroundColor Green
        } else {
            Write-Error "Failed to create image definition: $imgName"
        }
    }
    
    # Build DevCenter image reference
    $imgId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.DevCenter/devCenters/$devCenterName/galleries/$galleryName/images/$imgName"
    $imageMap[$imgName] = $imgId
}

Write-Host ""
Write-Host "Step 3: Grant DevCenter Access to Gallery" -ForegroundColor Yellow

# Get DevCenter identity information
$identityJson = az devcenter admin devcenter show --name $devCenterName --resource-group $resourceGroup --query "identity" -o json
$identity = $identityJson | ConvertFrom-Json

if (-not $identity) {
    Write-Error "DevCenter does not have a managed identity enabled"
    exit 1
}

# Get both system-assigned and user-assigned principal IDs
$systemPrincipalId = $identity.principalId
$userPrincipalId = ($identity.userAssignedIdentities.PSObject.Properties.Value | Select-Object -First 1).principalId

Write-Host "  System-Assigned Identity: $systemPrincipalId" -ForegroundColor Gray
Write-Host "  User-Assigned Identity: $userPrincipalId" -ForegroundColor Gray

# Gallery resource ID
$galleryResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Compute/galleries/$galleryName"

# Check and grant Reader role to system-assigned identity
$existingSystemRole = az role assignment list --assignee $systemPrincipalId --scope $galleryResourceId --query "[?roleDefinitionName=='Reader'].id" -o tsv 2>$null

if ($existingSystemRole) {
    Write-Host "  ✓ System-assigned identity already has Reader access" -ForegroundColor Green
} else {
    Write-Host "  Granting Reader role to system-assigned identity..." -ForegroundColor Cyan
    az role assignment create `
        --assignee $systemPrincipalId `
        --role "Reader" `
        --scope $galleryResourceId | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Reader role granted to system-assigned identity" -ForegroundColor Green
    } else {
        Write-Error "Failed to grant Reader role to system-assigned identity"
        exit 1
    }
}

# Check and grant Reader role to user-assigned identity
$existingUserRole = az role assignment list --assignee $userPrincipalId --scope $galleryResourceId --query "[?roleDefinitionName=='Reader'].id" -o tsv 2>$null

if ($existingUserRole) {
    Write-Host "  ✓ User-assigned identity already has Reader access" -ForegroundColor Green
} else {
    Write-Host "  Granting Reader role to user-assigned identity..." -ForegroundColor Cyan
    az role assignment create `
        --assignee $userPrincipalId `
        --role "Reader" `
        --scope $galleryResourceId | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Reader role granted to user-assigned identity" -ForegroundColor Green
    } else {
        Write-Error "Failed to grant Reader role to user-assigned identity"
        exit 1
    }
}

# Wait for role assignments to propagate
Write-Host "  ⏳ Waiting for role assignments to propagate (60 seconds)..." -ForegroundColor Cyan
Start-Sleep -Seconds 60

Write-Host ""
Write-Host "Step 4: Attach Gallery to DevCenter" -ForegroundColor Yellow

# Check if gallery is already attached
$attachedGalleries = az devcenter admin gallery list --dev-center $devCenterName --resource-group $resourceGroup --query "[?contains(galleryResourceId, '$galleryName')].name" -o tsv 2>$null
if ($attachedGalleries -and $attachedGalleries.Contains($galleryName)) {
    Write-Host "  ✓ Gallery already attached to DevCenter" -ForegroundColor Green
} else {
    Write-Host "  Attaching gallery to DevCenter..." -ForegroundColor Cyan
    
    az devcenter admin gallery create `
        --dev-center-name $devCenterName `
        --resource-group $resourceGroup `
        --gallery-name $galleryName `
        --gallery-resource-id $galleryResourceId
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Gallery attached successfully" -ForegroundColor Green
        Write-Host "  ⏳ Waiting for gallery synchronization (this may take a few minutes)..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30
    } else {
        Write-Error "Failed to attach gallery to DevCenter"
        exit 1
    }
}

Write-Host ""
Write-Host "Available Images:" -ForegroundColor Cyan
$imageMap.GetEnumerator() | ForEach-Object {
    Write-Host "  $($_.Key)" -ForegroundColor Gray
}

# Read devcenter-settings.json
Write-Host ""
Write-Host "Step 5: Create DevBox Definitions" -ForegroundColor Yellow
Write-Host "  Reading DevCenter settings..." -ForegroundColor Cyan
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

foreach ($def in $devCenterSettings.customizedImageDevboxdefinitions) {
    $defName = $def.name
    $imageType = $def.imageType
    $compute = $def.compute
    $storage = $def.storage
    
    # Get the image ID - support both custom images and default built-in
    if ($imageType -eq "default") {
        # Use built-in VS2022 image
        $imageId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.DevCenter/devCenters/$devCenterName/galleries/default/images/microsoftvisualstudio_visualstudioplustools_vs-2022-ent-general-win11-m365-gen2"
        Write-Host "  Using built-in VS2022 image for: $defName" -ForegroundColor Cyan
    }
    elseif (-not $imageMap.ContainsKey($imageType)) {
        Write-Host "  ⚠️  Warning: Image type '$imageType' not found in gallery" -ForegroundColor Yellow
        Write-Host "     Skipping definition '$defName'. Build the custom image first or use 'default' imageType." -ForegroundColor Yellow
        continue
    }
    else {
        $imageId = $imageMap[$imageType]
        Write-Host "  Using custom image for: $defName" -ForegroundColor Cyan
    }
    
    # Get the SKU
    if (-not $computeMap.ContainsKey($compute)) {
        Write-Error "Compute size '$compute' not mapped"
        continue
    }
    $skuName = $computeMap[$compute]
    
    # Map storage to os-storage-type - use proper format
    # Format should be: ssd_256gb, ssd_512gb, ssd_1024gb, ssd_2048gb
    $storageType = "ssd_$storage"
    
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

Write-Host ""
Write-Host "✓ DevBox definitions creation complete" -ForegroundColor Green

# Update project to allow dev box creation
Write-Host ""
Write-Host "Step 6: Update Project Settings" -ForegroundColor Yellow

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

Write-Host ""
Write-Host "Step 7: Update Packer Variables Files" -ForegroundColor Yellow

$packerDir = Join-Path $PSScriptRoot "packer"
if (Test-Path $packerDir) {
    Write-Host "  Updating Packer variable files with Terraform values..." -ForegroundColor Cyan
    
    # Get Azure account info
    $tenantId = az account show --query tenantId -o tsv
    
    # VS Code image variables
    $vsVarsFile = Join-Path $packerDir "vscode-variables.pkrvars.hcl"
    $vsVarsContent = @"
# Packer variables file for VS Code DevBox
# Auto-generated by 02-create-definitions.ps1

# Azure authentication
subscription_id = "$subscriptionId"
tenant_id      = "$tenantId"

# Azure resources
resource_group_name    = "$resourceGroup"
gallery_name          = "$galleryName"
image_definition_name = "VSCodeImage"
location             = "$location"

# Image configuration
image_version = "1.0.0"  # Increment this for new versions
vm_size      = "Standard_D2s_v3"

# Base image (Windows 11 Enterprise with Microsoft 365)
image_publisher = "MicrosoftWindowsDesktop"
image_offer    = "visualstudio-ent-cpc"
image_sku      = "win11-22h2-ent-cpc-m365-vscode"
"@
    
    Set-Content -Path $vsVarsFile -Value $vsVarsContent
    Write-Host "  ✓ Updated vscode-variables.pkrvars.hcl" -ForegroundColor Green
    
    # Visual Studio image variables
    $visualstudioVarsFile = Join-Path $packerDir "visualstudio-variables.pkrvars.hcl"
    $visualstudioVarsContent = @"
# Packer variables file for Visual Studio DevBox
# Auto-generated by 02-create-definitions.ps1

# Azure authentication
subscription_id = "$subscriptionId"
tenant_id      = "$tenantId"

# Azure resources
resource_group_name    = "$resourceGroup"
gallery_name          = "$galleryName"
image_definition_name = "VisualStudioImage"
location             = "$location"

# Image configuration
image_version = "1.0.0"  # Increment this for new versions
vm_size      = "Standard_D4s_v3"  # Larger VM size for Visual Studio

# Base image (Windows 11 with Visual Studio 2022 Enterprise)
image_publisher = "MicrosoftVisualStudio"
image_offer    = "visualstudioplustools"
image_sku      = "vs-2022-ent-general-win11-m365-gen2"
"@
    
    Set-Content -Path $visualstudioVarsFile -Value $visualstudioVarsContent
    Write-Host "  ✓ Updated visualstudio-variables.pkrvars.hcl" -ForegroundColor Green
    
    # IntelliJ image variables
    $intellijVarsFile = Join-Path $packerDir "intellij-variables.pkrvars.hcl"
    $intellijVarsContent = @"
# Packer variables file for IntelliJ DevBox
# Auto-generated by 02-create-definitions.ps1

# Azure authentication
subscription_id = "$subscriptionId"
tenant_id      = "$tenantId"

# Azure resources
resource_group_name    = "$resourceGroup"
gallery_name          = "$galleryName"
image_definition_name = "IntelliJDevImage"
location             = "$location"

# Image configuration
image_version = "1.0.0"  # Increment this for new versions
vm_size      = "Standard_D2s_v3"

# Base image (Windows 11 Enterprise with Microsoft 365)
image_publisher = "MicrosoftWindowsDesktop"
image_offer    = "windows-ent-cpc"
image_sku      = "win11-22h2-ent-cpc-m365"
"@
    
    Set-Content -Path $intellijVarsFile -Value $intellijVarsContent
    Write-Host "  ✓ Updated intellij-variables.pkrvars.hcl" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Packer directory not found, skipping variable file updates" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  ✓ Setup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. (Optional) Build custom images with Packer:" -ForegroundColor Gray
Write-Host "     cd packer" -ForegroundColor Gray
Write-Host "     .\build-image.ps1 -ImageType vscode -Action all" -ForegroundColor Gray
Write-Host "     .\build-image.ps1 -ImageType visualstudio -Action all" -ForegroundColor Gray
Write-Host "     .\build-image.ps1 -ImageType intellij -Action all" -ForegroundColor Gray
Write-Host "  2. Run 03-create-pools.ps1 to create the Dev Box pools" -ForegroundColor Gray
Write-Host ""
