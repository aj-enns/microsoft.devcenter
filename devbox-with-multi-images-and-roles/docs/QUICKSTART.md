# Quick Start Guide - DevBox Multi-Images and Roles

This guide will get you up and running quickly with the separated DevBox infrastructure.

## ⚡ 15-Minute Setup (Operations Team)

### Prerequisites Checklist
```powershell
# Check Azure CLI
az --version

# Check Terraform
terraform --version

# Login to Azure
az login

# Set subscription
az account set --subscription "your-subscription-name"
```

### Deploy Infrastructure

```powershell
# 1. Navigate to infrastructure folder
cd infrastructure

# 2. Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# 3. Edit with your values (minimum required):
# - resource_group_name = "rg-devbox-demo"
# - location = "eastus"
# - user_principal_id = "your-user-id"  # Get with: az ad signed-in-user show --query id -o tsv

# 4. Deploy everything
.\scripts\01-deploy-infrastructure.ps1

# 5. Attach networks
.\scripts\02-attach-networks.ps1

# 6. (Optional) Review Intune guidance
.\scripts\03-configure-intune.ps1
```

That's it! Infrastructure is ready. Now the image team can build custom images.

## ⚡ 20-Minute Image Build (Development Teams)

### Prerequisites Checklist
```powershell
# Check Packer
packer --version

# Check Azure CLI authentication
az account show

# Get infrastructure values from Operations team
terraform output -json  # Run this in infrastructure folder
```

### Build Your First Image

```powershell
# 1. Navigate to images folder
cd images/packer

# 2. Create variables file
cp teams/vscode-variables.pkrvars.hcl.example teams/vscode-variables.pkrvars.hcl

# 3. Edit teams/vscode-variables.pkrvars.hcl with values from Operations:
subscription_id = "..."          # From terraform output
tenant_id = "..."                # From terraform output
resource_group_name = "..."      # From terraform output
gallery_name = "..."             # From terraform output
location = "..."                 # From terraform output

# 4. Validate template
.\build-image.ps1 -ImageType vscode -ValidateOnly

# 5. Build image (takes 30-60 minutes)
.\build-image.ps1 -ImageType vscode
```

### Create DevBox Definition

```json
// Edit images/definitions/devbox-definitions.json
{
  "definitions": [
    {
      "name": "VSCode-DevBox",
      "imageDefinition": "VSCodeDevImage",
      "compute": "general_i_8c32gb256ssd_v2",
      "storage": "ssd_256gb",
      "team": "vscode-team"
    }
  ],
  "pools": [
    {
      "name": "VSCode-Development-Pool",
      "definitionName": "VSCode-DevBox",
      "administrator": "Enabled"
    }
  ]
}
```

### Sync Pools

```powershell
# Operations team runs:
cd ../../infrastructure/scripts
.\04-sync-pools.ps1
```

## 🎯 Your First DevBox

### Provision via Dev Portal

1. Go to https://devportal.microsoft.com
2. Sign in with your Azure AD account
3. Click "New" → "New Dev Box"
4. Select pool: "VSCode-Development-Pool"
5. Name your Dev Box
6. Click "Create"

Wait 15-30 minutes for provisioning.

### Connect to Your Dev Box

**Option 1: RDP Client (Recommended)**
1. In Dev Portal, find your Dev Box
2. Click "Connect"
3. Download RDP file
4. Open with Remote Desktop client

**Option 2: Web Browser**
1. Click "Open in browser"
2. Uses HTML5 RDP client

### Verify Setup

Once connected:

```powershell
# Check Azure AD join
dsregcmd /status
# Should show: AzureAdJoined : YES

# Check Intune enrollment
dsregcmd /status | Select-String MDM
# Should show MDM URL

# Verify tools installed
code --version
git --version
node --version
python --version
```

## 🔄 Daily Workflows

### For Operations Team

**Morning checks:**
```powershell
# Check network health
az devcenter admin network-connection show \
  --name <connection> --resource-group <rg> \
  --query healthCheckStatus

# Check active Dev Boxes
az devcenter dev dev-box list --project <project>
```

**When definitions updated:**
```powershell
cd infrastructure/scripts
.\04-sync-pools.ps1
```

### For Development Teams

**Update image with new tools:**
```powershell
# 1. Edit your team's Packer template
# Add new choco install line

# 2. Increment version
# Edit teams/vscode-variables.pkrvars.hcl
# image_version = "1.0.1"  # Was 1.0.0

# 3. Build
.\build-image.ps1 -ImageType vscode

# 4. Update definitions with new version
# Edit definitions/devbox-definitions.json

# 5. Create PR for review
```

**Add new DevBox definition:**
```json
// Edit definitions/devbox-definitions.json
{
  "definitions": [
    {
      "name": "New-DevBox-Config",
      "imageDefinition": "VSCodeDevImage",
      "compute": "general_i_16c64gb512ssd_v2",  // Larger size
      "storage": "ssd_512gb",
      "team": "vscode-team"
    }
  ]
}
```

## 🚨 Common Issues

**"Can't connect to Dev Box"**
- Wait full 30 minutes for first provision
- Check RDP client is updated
- Try web browser connection
- Verify user has "DevCenter Dev Box User" role

**"Image build failed"**
- Check Azure CLI is logged in: `az account show`
- Verify permissions on gallery
- Check Packer logs in console output
- Ensure base provisioners not modified

**"Pool not showing up"**
- Run `04-sync-pools.ps1` manually
- Check definition exists in DevCenter
- Verify image build completed successfully

**"Terraform fails"**
- Check Azure permissions (Contributor + User Access Admin)
- Verify subscription has capacity for resources
- Check terraform.tfvars has required values

## 📚 Next Steps

- Read full [README.md](README.md) for detailed documentation
- Review [compliance-settings.md](infrastructure/policies/compliance-settings.md)
- Set up [CI/CD pipelines](README.md#cicd-integration)
- Configure [Intune policies](README.md#operations-team-guide)

## 🆘 Get Help

- Infrastructure: @operations-team
- Images: Your team lead
- Documentation: README.md

---

**You're ready to go! Happy coding! 🚀**
