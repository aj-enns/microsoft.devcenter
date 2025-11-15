param(
    [string]$ResourceGroupName = "rg-devbox-learn-demo-tf",
    [string]$DevCenterName = "dc-devbox-test",
    [string]$ProjectName = "dcprj-devbox-test",
    [string]$GalleryName = "galwx1xi0xrsrl5c"
)

Write-Host "🔗 Step 4: Bind Dev Box definitions to custom images" -ForegroundColor Cyan

function Get-GalleryImageId {
    param(
        [string]$ImageDefinitionName,
        [string]$ImageVersion
    )

    $subscriptionId = (az account show --query id -o tsv)
    if (-not $subscriptionId) {
        throw "Unable to determine current subscription. Run 'az account show' to verify login."
    }

    return "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.DevCenter/devcenters/$DevCenterName/galleries/$GalleryName/images/$ImageDefinitionName/versions/$ImageVersion"
}

function Update-DevBoxDefinition {
    param(
        [string]$DevBoxDefinitionName,
        [string]$ImageDefinitionName,
        [string]$VariablesFile
    )

    if (-not (Test-Path $VariablesFile)) {
        Write-Warning "Variables file not found: $VariablesFile - skipping $DevBoxDefinitionName"
        return
    }

    Write-Host "" -ForegroundColor Gray
    Write-Host "📦 Updating Dev Box definition: $DevBoxDefinitionName" -ForegroundColor Yellow

    # Read image_version from the Packer variables file
    $imageVersion = (Get-Content $VariablesFile | Where-Object { $_ -match '^image_version' }) -replace 'image_version\s*=\s*"([^"]+)".*', '$1'
    if (-not $imageVersion) {
        Write-Warning "Could not determine image_version from $VariablesFile - skipping $DevBoxDefinitionName"
        return
    }

    $imageId = Get-GalleryImageId -ImageDefinitionName $ImageDefinitionName -ImageVersion $imageVersion

    Write-Host "  Image definition : $ImageDefinitionName" -ForegroundColor DarkGray
    Write-Host "  Image version    : $imageVersion" -ForegroundColor DarkGray
    Write-Host "  Image resourceId : $imageId" -ForegroundColor DarkGray

    $cmd = @(
        "az devcenter admin devbox-definition update",
        "--dev-center-name `"$DevCenterName`"",
        "--resource-group `"$ResourceGroupName`"",
        "--name `"$DevBoxDefinitionName`"",
        "--image-reference id=`"$imageId`""
    ) -join " "

    Write-Host "  Command: $cmd" -ForegroundColor DarkGray
    Write-Host "  Executing update..." -ForegroundColor DarkGray

    az devcenter admin devbox-definition update `
        --dev-center-name $DevCenterName `
        --resource-group $ResourceGroupName `
        --name $DevBoxDefinitionName `
        --image-reference id="$imageId"

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Updated successfully" -ForegroundColor Green
    } else {
        Write-Warning "  Failed to update ${DevBoxDefinitionName} (exit code: $LASTEXITCODE)"
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$packerFolder = Join-Path $scriptRoot "packer"

Update-DevBoxDefinition `
    -DevBoxDefinitionName "VSCode-DevBox-8core-32gb" `
    -ImageDefinitionName "VSCodeImage" `
    -VariablesFile (Join-Path $packerFolder "vscode-variables.pkrvars.hcl")

Update-DevBoxDefinition `
    -DevBoxDefinitionName "VisualStudio-DevBox-8core-32gb" `
    -ImageDefinitionName "VisualStudioImage" `
    -VariablesFile (Join-Path $packerFolder "visualstudio-variables.pkrvars.hcl")

Update-DevBoxDefinition `
    -DevBoxDefinitionName "IntelliJ-DevBox-8core-32gb" `
    -ImageDefinitionName "IntelliJDevImage" `
    -VariablesFile (Join-Path $packerFolder "intellij-variables.pkrvars.hcl")

Write-Host "" -ForegroundColor Gray
Write-Host "✅ Custom image bindings complete. New Dev Boxes from these definitions will use the Packer-built images." -ForegroundColor Green
