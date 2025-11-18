# DevBox Custom Images - Development Team Guide

This repository contains Packer templates and DevBox definitions for building team-specific custom images. **Development Teams** own and manage this repository, building customized DevBox images on top of the security baseline provided by Operations.

## 🎯 Architecture Overview

This solution demonstrates a **separation of duties** approach where image customization is separated from infrastructure management:

```
DevBox Solution Architecture
├── infrastructure/          # SEPARATE REPOSITORY - Operations Team
│   ├── terraform/          # Core infrastructure configuration
│   ├── modules/            # Reusable Terraform modules
│   ├── scripts/            # Automation scripts
│   └── policies/           # Compliance and security policies
│
└── images/                 # THIS REPOSITORY - Development Teams
    ├── packer/
    │   ├── base/          # Operations-controlled base templates (read-only)
    │   └── teams/         # Team-specific image customizations
    └── definitions/       # DevBox definitions managed by dev teams
```

### Repository Separation Benefits

| Concern | Infrastructure Repo (SEPARATE) | Images Repo (THIS) |
|---------|-------------------|-------------|
| **Ownership** | Operations Team | Development Teams |
| **Controls** | Networks, security, compliance | Software, tools, configurations |
| **PR Approvals** | @operations-team, @network-team, @security-team | @dev-leads, @team-leads |
| **Update Frequency** | Quarterly or as needed | Weekly or continuous |
| **Azure Resources** | DevCenter, Networks, Galleries | Gallery Images, Definitions |

### How It Works

1. **Operations builds** `SecurityBaselineImage` with mandatory security
2. **Your team builds** on top of the baseline, adding your tools
3. **You define** DevBox configurations (CPU, RAM, storage)
4. **Operations syncs** pools when you update definitions
5. **Users provision** Dev Boxes from your custom images

## 📋 Table of Contents

- [✅ Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📁 Repository Structure](#-repository-structure)
- [💻 Building Custom Images](#-building-custom-images)
- [📝 Managing Definitions](#-managing-definitions)
- [🧪 Testing Images](#-testing-images)
- [🔄 CI/CD Integration](#-cicd-integration)
- [🐛 Troubleshooting](#-troubleshooting)

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

### Step 2: Configure Your Team's Variables

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

### Step 3: Customize Your Template (Optional)

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

### Step 4: Build Your Image

```powershell
# Validate template
.\build-image.ps1 -ImageType vscode -ValidateOnly

# Build image (30-60 minutes)
.\build-image.ps1 -ImageType vscode
```

### Step 5: Update Definitions

Edit `definitions/devbox-definitions.json`:

```json
{
  "definitions": [
    {
      "name": "VSCode-DevBox",
      "imageDefinition": "VSCodeDevImage",
      "compute": "general_i_8c32gb256ssd_v2",
      "storage": "ssd_256gb",
      "team": "vscode-team"
    }
  ]
}
```

### Step 6: Create Pull Request

1. Commit changes: `git commit -am "Add VS Code DevBox v1.0.0"`
2. Push to branch: `git push origin feature/vscode-devbox`
3. Create PR for team lead review
4. After merge, notify Operations to sync pools

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

### Step 3: Validate Template

```powershell
.\build-image.ps1 -ImageType vscode -ValidateOnly
```

This checks:
- Packer syntax is valid
- Variables are properly defined
- Azure authentication is working
- Source image (SecurityBaselineImage) exists

### Step 4: Build Image

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
      "imageDefinition": "VSCodeDevImage",
      "compute": "general_i_8c32gb256ssd_v2",
      "storage": "ssd_256gb",
      "team": "vscode-team",
      "autoUpdate": true,
      "description": "VS Code with Node.js, Python, Docker"
    },
    {
      "name": "IntelliJ-DevBox",
      "imageDefinition": "IntelliJDevImage",
      "compute": "general_i_16c64gb512ssd_v2",
      "storage": "ssd_512gb",
      "team": "java-team",
      "description": "IntelliJ IDEA with Java 17, Maven, Gradle"
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

Pools define auto-stop schedules and access:

```json
{
  "pools": [
    {
      "name": "VSCode-Development-Pool",
      "definitionName": "VSCode-DevBox",
      "administrator": "Enabled",      // LocalAdministrator access
      "schedule": {
        "time": "17:00",               // Auto-stop at 5 PM
        "timeZone": "Eastern Standard Time"
      }
    }
  ]
}
```

**Administrator Access:**
- `Enabled`: Users have local admin rights (install software)
- `Disabled`: Standard user access only

**Auto-Stop Schedule:**
- Saves costs by shutting down Dev Boxes
- Users can start them again when needed
- Recommended: After work hours (5 PM, 6 PM, etc.)

### Syncing Pools

After updating definitions:

1. Commit and push changes
2. Create PR for review
3. Merge to main
4. **Notify Operations Team** to run sync script:
   ```powershell
   # Operations runs this in infrastructure repo
   .\scripts\04-sync-pools.ps1
   ```

Or set up CI/CD to trigger automatically (see CI/CD section).

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

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/build-images.yml
name: Build DevBox Images

on:
  push:
    branches: [main]
    paths:
      - 'packer/teams/**'
      - 'definitions/**'
  pull_request:
    paths:
      - 'packer/**'

jobs:
  validate:
    runs-on: windows-latest
    strategy:
      matrix:
        image: [vscode, intellij, dotnet]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Packer
        uses: hashicorp/setup-packer@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Packer Init
        working-directory: packer
        run: packer init teams/${{ matrix.image }}-devbox.pkr.hcl
      
      - name: Packer Validate
        working-directory: packer
        run: |
          packer validate `
            -var-file=teams/${{ matrix.image }}-variables.pkrvars.hcl `
            teams/${{ matrix.image }}-devbox.pkr.hcl

  build:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: windows-latest
    strategy:
      matrix:
        image: [vscode]  # Build one at a time to avoid quota issues
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Packer
        uses: hashicorp/setup-packer@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build Image
        working-directory: packer
        run: .\build-image.ps1 -ImageType ${{ matrix.image }}
      
      - name: Notify Operations
        if: success()
        run: |
          # Trigger webhook or send notification
          # Operations will run pool sync
          echo "Image built successfully - notify ops team"

  notify-ops:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    
    steps:
      - name: Trigger Pool Sync
        run: |
          # Call webhook in operations repo
          curl -X POST ${{ secrets.OPS_WEBHOOK_URL }} \
            -H "Authorization: Bearer ${{ secrets.WEBHOOK_TOKEN }}" \
            -d '{"action": "sync-pools", "repo": "images"}'
```

### Azure DevOps Pipeline Example

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - packer/**
      - definitions/**

pool:
  vmImage: 'windows-latest'

stages:
  - stage: Validate
    jobs:
      - job: ValidatePacker
        steps:
          - task: PackerTool@0
            inputs:
              version: 'latest'
          
          - task: AzureCLI@2
            inputs:
              azureSubscription: 'DevBox-ServiceConnection'
              scriptType: 'pscore'
              scriptLocation: 'inlineScript'
              inlineScript: |
                cd packer
                packer init teams/vscode-devbox.pkr.hcl
                packer validate -var-file=teams/vscode-variables.pkrvars.hcl teams/vscode-devbox.pkr.hcl
  
  - stage: Build
    condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
    jobs:
      - job: BuildImage
        timeoutInMinutes: 90
        steps:
          - task: AzureCLI@2
            inputs:
              azureSubscription: 'DevBox-ServiceConnection'
              scriptType: 'pscore'
              scriptLocation: 'inlineScript'
              inlineScript: |
                cd packer
                ./build-image.ps1 -ImageType vscode
```

## 🐛 Troubleshooting

### Build Issues

**Problem: Packer authentication fails**

```powershell
# Verify Azure CLI login
az account show

# Check permissions on gallery
az role assignment list \
  --assignee <your-user-id> \
  --scope <gallery-resource-id>
```

**Solution:** Ensure you have Reader role on the gallery (ask Operations).

**Problem: SecurityBaselineImage not found**

```
Error: Image 'SecurityBaselineImage' not found in gallery
```

**Solution:** Operations team must build the baseline first:
```powershell
# Operations runs this
cd images/packer/base
.\build-baseline-image.ps1 -ImageVersion "1.0.0"
```

**Problem: Build timeout or slow**

```hcl
# Increase VM size in your variables file
vm_size = "Standard_D4s_v3"  # Faster than D2s_v3
```

**Problem: Chocolatey package fails**

```powershell
# Add retry logic in provisioner
provisioner "powershell" {
  inline = [
    "$maxRetries = 3",
    "for ($i = 0; $i -lt $maxRetries; $i++) {",
    "  try {",
    "    choco install -y your-package",
    "    break",
    "  } catch {",
    "    Write-Output 'Retry attempt ' ($i + 1)",
    "    Start-Sleep -Seconds 10",
    "  }",
    "}"
  ]
}
```

### Definition Issues

**Problem: Pool not created after definition update**

```powershell
# Manually sync (ask Operations to run)
cd infrastructure/scripts
.\04-sync-pools.ps1 -Verbose
```

**Problem: Invalid compute SKU**

Valid SKUs (check with Operations for full list):
- `general_i_8c32gb256ssd_v2`
- `general_i_16c64gb512ssd_v2`
- `general_i_32c128gb1024ssd_v2`

**Problem: Image version not found**

Ensure the image version you specified in definition exists:
```powershell
az sig image-version list \
  --gallery-name <gallery> \
  --gallery-image-definition VSCodeDevImage \
  --resource-group <rg>
```

### Dev Box Issues

**Problem: Dev Box stuck in "Creating" state**

Check:
- Image exists in gallery
- Network connection is healthy (ask Operations)
- Quota limits not exceeded
- Azure Activity Log for errors

**Problem: Can't connect to Dev Box**

- Verify network security group rules
- Check if you have "DevCenter Dev Box User" role
- Ensure RDP client is updated
- Try web-based connection from Dev Portal

**Problem: Tools not working in Dev Box**

Common causes:
- Tool wasn't installed during build (check Packer logs)
- Path environment variable not set
- Tool requires restart (reboot Dev Box)
- License activation needed

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

### Microsoft Documentation
- [Microsoft DevCenter Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Custom Image Requirements](https://learn.microsoft.com/azure/dev-box/how-to-configure-dev-box-azure-image-builder)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure)

### Packer Templates
- [Packer HCL Reference](https://www.packer.io/docs/templates/hcl_templates)
- [Azure ARM Builder](https://www.packer.io/plugins/builders/azure/arm)
- [Provisioners](https://www.packer.io/docs/provisioners)

### Best Practices
- [Packer Best Practices](https://www.packer.io/guides/packer-on-cicd)
- [Image Versioning Guidelines](https://semver.org/)

### Related Repositories
- **Infrastructure Repository**: Contains Terraform for DevCenter, networks, and galleries
- Operations team manages core infrastructure there

## 🤝 Contributing

### Pull Request Process
1. Create feature branch from main
2. Make changes to your team's Packer templates or definitions
3. Run `.\build-image.ps1 -ImageType <your-image> -ValidateOnly`
4. Test image build locally
5. Create PR with description
6. Required approvals:
   - Team Lead
   - (Operations team notified but not required)
7. Merge to main triggers CI/CD build

### Code Ownership (CODEOWNERS)

```
# Base templates (Operations only)
/packer/base/ @operations-team

# Team templates
/packer/teams/vscode* @vscode-team-leads
/packer/teams/intellij* @java-team-leads
/packer/teams/dotnet* @dotnet-team-leads

# Definitions (Team leads + Operations)
/definitions/ @dev-leads @operations-team
```

## 🆘 Support

For issues or questions:
- **Image build issues**: Contact your team lead
- **Definition/pool issues**: Contact @operations-team
- **Gallery access issues**: Contact @operations-team
- **General questions**: Create GitHub issue

## 📞 Getting Started Help

**First time building an image?**
1. Get values from Operations team (subscription, gallery name, etc.)
2. Configure your variables file
3. Run validation: `.\build-image.ps1 -ImageType <your-team> -ValidateOnly`
4. If validation passes, build: `.\build-image.ps1 -ImageType <your-team>`
5. Update definitions and create PR

**Need baseline image version?**
Ask Operations team for latest SecurityBaselineImage version:
```powershell
# Operations can run:
az sig image-version list \
  --gallery-name <gallery> \
  --gallery-image-definition SecurityBaselineImage \
  --resource-group <rg> \
  --query "[0].name"
```

---

**Development Teams - Build Your Perfect Development Environment! 🚀**
