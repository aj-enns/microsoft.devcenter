# DevBox Custom Images - Development Team Guide

This repository contains Packer templates and DevBox definitions for building team-specific custom images. **Development Teams** own and manage this repository, building customized DevBox images on top of the security baseline provided by Operations.

## 🎯 Quick Overview

This repository contains everything you need to build custom DevBox images for your team:

```
images/
├── packer/
│   ├── base/          # Operations-controlled baseline (read-only)
│   └── teams/         # Your team's customizations (edit these!)
└── definitions/       # DevBox configurations (CPU, RAM, storage)
```

### How It Works

1. **You build** custom images with your team's tools (Packer)
2. **You configure** DevBox specs (CPU, RAM, storage) in definitions file
3. **You submit** PR with your changes
4. **Operations deploys** your definitions to Azure DevCenter
5. **Users provision** Dev Boxes from your custom images

## 📋 Table of Contents

- [✅ Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📁 Repository Structure](#-repository-structure)
- [💻 Building Custom Images](#-building-custom-images)
- [📝 Managing Definitions](#-managing-definitions)
- [🧪 Testing Images](#-testing-images)
- [🐛 Troubleshooting](#-troubleshooting)
- [📚 Common Software](#-common-software-installations)

## ✅ Prerequisites

### Required Tools
- Packer v1.9+
- Azure CLI installed and authenticated (`az login`)
- PowerShell 7+ (for build scripts)
- Git for version control

### Required Access
- Reader role on Azure Compute Gallery (granted by Operations)
- Azure CLI authentication to the subscription
- Access to this repository with write permissions

### Information from Operations Team
You'll need these values from Operations (from their Terraform outputs):
- `subscription_id` - Azure subscription ID
- `resource_group_name` - Resource group containing gallery
- `gallery_name` - Azure Compute Gallery name
- `location` - Azure region
- `baseline_image_version` - Version of SecurityBaselineImage to use

## 🚀 Quick Start

### Step 1: Clone Repository

```powershell
git clone <images-repo-url>
cd images/packer
```

### Step 2: Create Image Definition (First Time Only)

Before building your first image, create the image definition in the Azure Compute Gallery:

```powershell
cd teams
.\create-image-definition.ps1 -ImageType vscode -ResourceGroup <rg-name> -GalleryName <gallery-name>
cd ..
```

**Example:**
```powershell
cd teams
.\create-image-definition.ps1 -ImageType vscode -ResourceGroup rg-devbox-multi-roles -GalleryName galxvqypooxvqja4
cd ..
```

This creates the image definition with:
- TrustedLaunch security type
- Hibernation support enabled
- Proper publisher/offer/SKU metadata
- Windows OS, Generalized state

**Note:** This is a one-time setup per image type. If the definition already exists, the script will skip creation.

### Step 3: Configure Your Team's Variables

```powershell
# Copy example file
cp teams/vscode-variables.pkrvars.hcl.example teams/vscode-variables.pkrvars.hcl
```

Edit with values from Operations Team:

```hcl
# Azure subscription where resources will be created
subscription_id = "00000000-0000-0000-0000-000000000000"

# Resource group containing the Azure Compute Gallery
resource_group_name = "rg-devbox-multi-roles"

# Name of the Azure Compute Gallery
gallery_name = "galdevbox"

# Version of SecurityBaselineImage to build from
baseline_image_version = "1.0.0"

# Version for this VS Code team image
image_version = "1.0.0"

# Azure region for temporary build resources
location = "eastus"

# VM size for the build process
vm_size = "Standard_D2s_v3"
```

### Step 4: Customize Your Template (Optional)

Edit `teams/vscode-devbox.pkr.hcl` to add your team's tools:

```hcl
provisioner "powershell" {
  inline = [
    "choco install -y nodejs",
    "choco install -y docker-desktop",
    "# Add your custom configurations"
  ]
}
```

### Step 5: Build Your Image

```powershell
# Validate template
.\build-image.ps1 -ImageType vscode -ValidateOnly

# Build image (30-60 minutes)
.\build-image.ps1 -ImageType vscode

# Optional: Enable logging for troubleshooting
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "vscode-packer.log"
.\build-image.ps1 -ImageType vscode
```

### Step 6: Update Definitions

Edit `definitions/devbox-definitions.json` to reference your new image:

```json
{
  "definitions": [
    {
      "name": "VSCode-DevBox",
      "imageName": "VSCodeDevImage",
      "imageVersion": "1.0.0",
      "computeSku": "general_i_8c32gb256ssd_v2",
      "storageType": "ssd_256gb",
      "hibernationSupport": "Disabled",
      "team": "vscode-team",
      "description": "VS Code with Node.js, Docker"
    }
  ]
}
```

### Step 7: Validate Configuration

```powershell
cd definitions
# Check JSON syntax and schema
Get-Content devbox-definitions.json | ConvertFrom-Json
```

### Step 8: Create Pull Request

1. Commit changes: `git commit -am "Add VS Code DevBox v1.0.0"`
2. Push to branch: `git push origin feature/vscode-devbox`
3. Create PR for team lead review
4. **After merge**: Operations team will deploy your definitions

## 📁 Repository Structure

```
images/
├── packer/
│   ├── base/              # Operations-controlled (READ-ONLY)
│   │   ├── security-baseline.pkr.hcl       # Golden baseline template
│   │   ├── security-baseline.pkrvars.hcl   # Baseline variables
│   │   ├── build-baseline-image.ps1        # Baseline build script
│   │   ├── create-image-definition.ps1     # Create baseline definition
│   │   └── windows-base.pkr.hcl            # Base Windows config
│   │
│   ├── teams/             # YOUR CUSTOMIZATIONS
│   │   ├── create-image-definition.ps1     # Create team image definition
│   │   ├── vscode-devbox.pkr.hcl
│   │   ├── vscode-variables.pkrvars.hcl
│   │   ├── vscode-variables.pkrvars.hcl.example
│   │   ├── intellij-devbox.pkr.hcl
│   │   ├── intellij-variables.pkrvars.hcl
│   │   └── dotnet-devbox.pkr.hcl
│   │
│   └── build-image.ps1    # Image build script for team images
│
├── definitions/
│   └── devbox-definitions.json         # DevBox configurations
│
├── CODEOWNERS             # Team-specific ownership
└── README.md              # This file
```

### Base Templates (Operations-Controlled)

⚠️ **DO NOT MODIFY** files in `packer/base/`

The Operations team maintains the `SecurityBaselineImage` which contains:
- ✅ Windows hardening and security policies
- ✅ Azure AD join capability (required for Intune)
- ✅ Security baseline (Windows Defender, Firewall)
- ✅ Compliance tools (Azure CLI, monitoring agents)
- ✅ Base tooling (Git, Visual Studio Code)
- ✅ Organization-wide configurations

**Why can't you modify these?**
- Removing Azure AD configuration breaks Intune enrollment
- Disabling security tools violates compliance policies
- These settings are organizationally mandated

**You build on top** of this baseline by creating team-specific images in `teams/`.

## 💻 Building Custom Images

### Understanding the Build Process

Your team image builds **on top of** the SecurityBaselineImage:

```
SecurityBaselineImage (v1.0.0)         ← Built by Operations
    ↓ (your template uses as source)
VSCodeDevImage (v1.0.0)                ← Built by your team
    ↓ (adds VS Code specific tools)
    • Node.js, npm
    • Docker Desktop
    • VS Code extensions
    • Team configurations
```

### Step 1: Create Variable File

```powershell
cd images/packer
cp teams/vscode-variables.pkrvars.hcl.example teams/vscode-variables.pkrvars.hcl
```

Edit with values provided by Operations Team:

```hcl
# Required values from Operations Team
subscription_id        = "<from-ops-team>"
resource_group_name    = "<from-ops-team>"
gallery_name           = "<from-ops-team>"
location               = "<from-ops-team>"

# Baseline version (ask Operations for latest)
baseline_image_version = "1.0.0"

# Your image version
image_version = "1.0.0"  # Increment for new builds

# Build configuration
vm_size = "Standard_D2s_v3"
```

**Note:** The image name (`VSCodeDevImage`, `IntelliJDevImage`, etc.) is predefined in your Packer template.

### Step 2: Customize Packer Template

Edit your team's `.pkr.hcl` file to add tools:

```hcl
# Example: teams/vscode-devbox.pkr.hcl

build {
  sources = ["source.azure-arm.vscode_devbox"]
  
  # Your customizations (Order: 10-99)
  provisioner "powershell" {
    inline = [
      "Write-Host 'Installing Node.js...'",
      "choco install -y nodejs --version=20.10.0",
      "",
      "Write-Host 'Installing Docker Desktop...'",
      "choco install -y docker-desktop",
      "",
      "Write-Host 'Configuring VS Code...'",
      "code --install-extension ms-vscode.vscode-typescript-next",
      "code --install-extension dbaeumer.vscode-eslint"
    ]
  }
}
```

**Rules:**
- ✅ Can add software installations
- ✅ Can configure development tools
- ✅ Can create directories and shortcuts
- ✅ Can set environment variables
- ❌ Cannot modify source (SecurityBaselineImage)
- ❌ Cannot disable Windows Defender or Firewall
- ❌ Cannot remove Azure AD join configuration
- ❌ Cannot skip compliance provisioners

### Step 4: Validate Template

```powershell
.\build-image.ps1 -ImageType vscode -ValidateOnly
```

This checks:
- Packer syntax is valid
- Variables are properly defined
- Azure authentication is working
- Source image (SecurityBaselineImage) exists
- Target image definition (VSCodeDevImage) exists

### Step 5: Build Image

```powershell
# Full build (30-60 minutes)
.\build-image.ps1 -ImageType vscode

# With custom variables file
.\build-image.ps1 -ImageType vscode -VarFile custom-vars.pkrvars.hcl
```

**Build Process:**
1. Creates temporary VM in Azure (in your subscription)
2. Pulls SecurityBaselineImage from gallery
3. Applies your team customizations
4. Runs validation checks
5. Generalizes (sysprep) the image
6. Uploads to Azure Compute Gallery
7. Cleans up temporary resources

**Build Time:** 30-60 minutes depending on:
- Number of tools installed
- VM size used for building
- Network speed
- Chocolatey package download times

### Image Versioning

Use semantic versioning for your images:

| Version | Use Case | Example |
|---------|----------|---------|
| `1.0.0` | Initial release | First VS Code DevBox image |
| `1.0.1` | Patch (bug fixes, security updates) | Fixed VS Code configuration |
| `1.1.0` | Minor (new tools, non-breaking) | Added Docker Desktop |
| `2.0.0` | Major (breaking changes, upgrades) | Node.js 18→20, removed old tools |

Update `image_version` in your variables file for each new build:

```hcl
image_version = "1.1.0"  # Increment this
```

## 📝 Managing Definitions

### DevBox Definitions

Definitions specify the VM size, storage, and image for Dev Boxes.

Edit `definitions/devbox-definitions.json`:

```json
{
  "definitions": [
    {
      "name": "VSCode-DevBox",
      "imageName": "VSCodeDevImage",
      "imageVersion": "1.0.0",
      "computeSku": "general_i_8c32gb256ssd_v2",
      "storageType": "ssd_256gb",
      "hibernationSupport": "Disabled",
      "team": "vscode-team",
      "description": "VS Code with Node.js, Python, Docker"
    },
    {
      "name": "Java-DevBox",
      "imageName": "JavaDevImage",
      "imageVersion": "1.0.1",
      "computeSku": "general_i_8c32gb256ssd_v2",
      "storageType": "ssd_256gb",
      "hibernationSupport": "Disabled",
      "team": "java-team",
      "description": "Java with OpenJDK, Maven, IntelliJ"
    }
  ],
  "pools": [
    {
      "name": "VSCode-Development-Pool",
      "definitionName": "VSCode-DevBox",
      "administrator": "Enabled",
      "schedule": {
        "time": "17:00",
        "timeZone": "Eastern Standard Time"
      }
    }
  ]
}
```

### DevBox Compute SKUs

| SKU | vCPUs | RAM | Storage | Use Case |
|-----|-------|-----|---------|----------|
| `general_i_8c32gb256ssd_v2` | 8 | 32 GB | 256 GB | Web dev, scripting, lightweight IDEs |
| `general_i_16c64gb512ssd_v2` | 16 | 64 GB | 512 GB | Java, .NET, large projects |
| `general_i_32c128gb1024ssd_v2` | 32 | 128 GB | 1 TB | ML, data science, heavy workloads |

**Choosing the Right SKU:**
- **8 vCPUs**: VS Code, lightweight development
- **16 vCPUs**: IntelliJ, Visual Studio, medium projects
- **32 vCPUs**: Android Studio, ML workloads, large monorepos

### Pool Configuration

Pools define auto-stop schedules and access levels:

```json
{
  "pools": [
    {
      "name": "VSCode-Development-Pool",
      "definitionName": "VSCode-DevBox",
      "administrator": "Enabled",
      "schedule": {
        "time": "17:00",
        "timeZone": "Eastern Standard Time"
      }
    }
  ]
}
```

**Administrator Access:**
- `Enabled`: Users have local admin rights (can install software)
- `Disabled`: Standard user access only

**Auto-Stop Schedule:**
- Saves costs by shutting down Dev Boxes after hours
- Users can restart them when needed
- Recommended: After work hours (17:00-18:00)

### Requesting Deployment

After updating definitions:

1. Commit and push changes
2. Create PR for team lead review
3. Merge to main
4. **Operations team will deploy** your updated definitions automatically (or notify them if needed)

## 🧪 Testing Images

### Before Production Release

1. **Build test image:**
   ```powershell
   # Use test version number
   image_version = "1.1.0-test"
   .\build-image.ps1 -ImageType vscode
   ```

2. **Create test definition:**
   ```json
   {
     "name": "VSCode-DevBox-Test",
     "imageDefinition": "VSCodeDevImage",
     "imageVersion": "1.1.0-test",  // Pin to test version
     "compute": "general_i_8c32gb256ssd_v2"
   }
   ```

3. **Provision test Dev Box:**
   - Go to Dev Portal
   - Create Dev Box from test pool
   - Wait 15-20 minutes for provisioning

4. **Verification Checklist:**
   - ✅ All tools installed correctly
   - ✅ Tools launch without errors
   - ✅ Azure AD join successful: `dsregcmd /status`
   - ✅ Intune enrollment successful
   - ✅ Compliance policies applied
   - ✅ Network connectivity works
   - ✅ User experience is smooth

5. **Production release:**
   ```hcl
   # Remove -test suffix
   image_version = "1.1.0"
   ```
   
   Rebuild and update production definitions.

### Testing Commands

```powershell
# On the Dev Box, verify Azure AD join
dsregcmd /status
# Look for: AzureAdJoined : YES

# Check installed software
Get-Command node
Get-Command docker
Get-Command code

# Verify Windows Defender
Get-MpComputerStatus

# Check Firewall
Get-NetFirewallProfile | Select Name, Enabled
```



## 🐛 Troubleshooting

### Debugging Packer Builds

**Enable detailed Packer logging:**

```powershell
# PowerShell - Enable logging
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "packer.log"
.\build-image.ps1 -ImageType vscode

# View the log
Get-Content packer.log -Tail 50

# Find errors
Get-Content packer.log | Select-String -Pattern "error|failed|exit code"
```

**Common log patterns:**
- `exit code 50` - PowerShell syntax errors (often special characters like ✓, ⚠)
- `exit code 1` - Provisioner failure (check command output)
- `WinRM timeout` - Network or VM size issues

**Prevent build interruptions:**

Packer builds take 30-60 minutes and need continuous connection:

```powershell
# Disable computer sleep during build
powercfg /change standby-timeout-ac 0
.\build-image.ps1 -ImageType vscode

# Re-enable after build completes
powercfg /change standby-timeout-ac 15
```

### Build Issues

**Problem: Packer authentication fails**

```powershell
# Verify Azure CLI login
az account show

# Re-authenticate if needed
az login
```

**Solution:** Ensure you're logged into the correct subscription and have gallery access (ask Operations if needed).

**Problem: SecurityBaselineImage not found**

```
Error: Image 'SecurityBaselineImage' not found in gallery
```

**Solution:** Ask Operations team to build the baseline image first, or verify the `baseline_image_version` in your variables file.

**Problem: Build is slow or times out**

```hcl
# Increase VM size in your variables file
vm_size = "Standard_D4s_v3"  # Faster than D2s_v3
```

**Problem: Chocolatey package installation fails**

```powershell
# Add retry logic in your provisioner
provisioner "powershell" {
  inline = [
    "$maxRetries = 3",
    "for ($i = 0; $i -lt $maxRetries; $i++) {",
    "  try {",
    "    choco install -y nodejs",
    "    break",
    "  } catch {",
    "    Write-Host 'Retry ' ($i + 1)",
    "    Start-Sleep -Seconds 10",
    "  }",
    "}"
  ]
}
```

**Problem: WSL not working in Dev Box**

Ensure your provisioner runs `wsl --update` fully (not silenced with `Out-Null`):

```powershell
provisioner "powershell" {
  inline = [
    "Write-Host 'Installing WSL 2...'",
    "wsl --update",
    "wsl --set-default-version 2",
    "wsl --install -d Ubuntu --web-download --no-launch",
    "wsl --version"
  ]
}
```

### Definition Issues

**Problem: Invalid compute SKU**

Check with Operations team for valid SKUs. Common ones:
- `general_i_8c32gb256ssd_v2` (8 vCPU, 32 GB, 256 GB)
- `general_i_16c64gb512ssd_v2` (16 vCPU, 64 GB, 512 GB)
- `general_i_32c128gb1024ssd_v2` (32 vCPU, 128 GB, 1 TB)

**Problem: Image version not found**

Verify the image version exists in the gallery:

```powershell
az sig image-version list \
  --gallery-name <gallery> \
  --gallery-image-definition VSCodeDevImage \
  --resource-group <rg> \
  --query "[].name" -o table
```

Ensure `imageVersion` in your definitions file matches a built version.

### Testing Your Image

**Problem: Tools not working in Dev Box**

Common causes:
- Tool wasn't installed during build (check Packer logs)
- Path environment variable not set correctly
- Tool requires system restart
- License activation needed (e.g., Visual Studio, IntelliJ)

**Verification checklist on Dev Box:**

```powershell
# Check installed tools
Get-Command node
Get-Command docker
Get-Command code

# Verify versions
node --version
docker --version

# Check environment variables
$env:PATH -split ';' | Select-String -Pattern 'nodejs'
```

## 📚 Common Software Installations

### Package Managers

```powershell
# Chocolatey (already in baseline)
choco install -y package-name

# Winget
choco install -y winget
winget install -e --id PackageId
```

### Development Tools

```powershell
# Version Control
choco install -y git
choco install -y github-desktop

# IDEs
choco install -y vscode
choco install -y visualstudio2022enterprise
choco install -y jetbrains-rider
choco install -y intellijidea-community
choco install -y pycharm-community

# Text Editors
choco install -y notepadplusplus
choco install -y sublimetext4
```

### Languages and Runtimes

```powershell
# Node.js
choco install -y nodejs --version=20.10.0

# Python
choco install -y python --version=3.11.7

# .NET
choco install -y dotnet-sdk --version=8.0.100

# Java
choco install -y openjdk17
choco install -y maven
choco install -y gradle

# Go
choco install -y golang

# Rust
choco install -y rust
```

### Containers and Cloud

```powershell
# Docker
choco install -y docker-desktop

# Kubernetes
choco install -y kubernetes-cli
choco install -y kubernetes-helm

# Cloud CLIs
choco install -y azure-cli
choco install -y awscli
choco install -y gcloudsdk

# Infrastructure
choco install -y terraform
choco install -y packer
```

### Databases

```powershell
# SQL Server Management Studio
choco install -y sql-server-management-studio

# Database Tools
choco install -y azure-data-studio
choco install -y dbeaver

# Databases
choco install -y postgresql
choco install -y mongodb
choco install -y redis
choco install -y mysql
```

## 📚 Additional Resources

### Packer Documentation
- [Packer HCL Templates](https://www.packer.io/docs/templates/hcl_templates)
- [Azure ARM Builder](https://www.packer.io/plugins/builders/azure/arm)
- [PowerShell Provisioner](https://www.packer.io/docs/provisioners/powershell)
- [Packer Best Practices](https://www.packer.io/guides/packer-on-cicd)

### DevBox Documentation
- [DevBox Custom Images](https://learn.microsoft.com/azure/dev-box/how-to-configure-dev-box-azure-image-builder)
- [Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/azure-compute-gallery)

### Versioning
- [Semantic Versioning](https://semver.org/)

## 🤝 Contributing

### Pull Request Workflow

1. **Create feature branch**
   ```powershell
   git checkout -b feature/vscode-v1.1.0
   ```

2. **Make changes** to your team's templates or definitions
   - Edit `packer/teams/your-team-devbox.pkr.hcl`
   - Update `definitions/devbox-definitions.json`

3. **Validate locally**
   ```powershell
   cd packer
   .\build-image.ps1 -ImageType your-team -ValidateOnly
   ```

4. **Test build** (optional but recommended)
   ```powershell
   .\build-image.ps1 -ImageType your-team
   ```

5. **Create PR** with clear description of changes

6. **Team lead reviews and approves**

7. **Merge to main** - Operations team deploys automatically

## 🆘 Support

**For help with:**
- **Packer build errors**: Check troubleshooting section above or contact your team lead
- **Template questions**: Review examples in `packer/teams/` folder
- **Gallery access**: Contact Operations team
- **Definition format**: See JSON examples in this README

## 📞 First Time Setup

**Building your first image?**

1. **Get configuration values** from Operations team:
   - `subscription_id`
   - `resource_group_name`
   - `gallery_name`
   - `baseline_image_version`
   - `location`

2. **Create image definition** (one-time setup):
   ```powershell
   cd packer/teams
   .\create-image-definition.ps1 -ImageType vscode -ResourceGroup <rg> -GalleryName <gallery>
   ```

3. **Configure variables** file with values from step 1

4. **Validate template**:
   ```powershell
   cd ..
   .\build-image.ps1 -ImageType vscode -ValidateOnly
   ```

5. **Build image**:
   ```powershell
   .\build-image.ps1 -ImageType vscode
   ```

6. **Update definitions** and create PR

---

**Development Teams - Build Your Perfect Development Environment! 🚀**
