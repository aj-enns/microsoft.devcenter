# DevBox Infrastructure - Operations Team Guide

This repository contains the infrastructure-as-code for Microsoft DevCenter with custom images. The **Operations Team** owns and manages this repository, which provisions the core Azure resources required for DevBox environments.

## 🎯 Architecture Overview

This solution demonstrates a **separation of duties** approach where infrastructure management is separated from image customization:

```
DevBox Solution Architecture
├── infrastructure/          # THIS REPOSITORY - Operations Team
│   ├── terraform/          # Core infrastructure configuration
│   ├── modules/            # Reusable Terraform modules
│   ├── scripts/            # Automation scripts
│   └── policies/           # Compliance and security policies
│
└── images/                 # SEPARATE REPOSITORY - Development Teams
    ├── packer/
    │   ├── base/          # Operations-controlled base templates
    │   └── teams/         # Team-specific image customizations
    └── definitions/       # DevBox definitions managed by dev teams
```

### Repository Separation Benefits

| Concern | Infrastructure Repo (THIS) | Images Repo (SEPARATE) |
|---------|-------------------|-------------|
| **Ownership** | Operations Team | Development Teams |
| **Controls** | Networks, security, compliance | Software, tools, configurations |
| **PR Approvals** | @operations-team, @network-team, @security-team | @dev-leads, @team-leads |
| **Update Frequency** | Quarterly or as needed | Weekly or continuous |
| **Azure Resources** | DevCenter, Networks, Galleries | Gallery Images, Definitions |

## 📋 Table of Contents

- [✅ Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📁 Repository Structure](#-repository-structure)
- [👔 Operations Workflow](#-operations-workflow)
- [🔧 Network Configuration](#-network-configuration)
- [🔐 Security & Compliance](#-security--compliance)
- [📊 Monitoring & Maintenance](#-monitoring--maintenance)
- [🔄 CI/CD Integration](#-cicd-integration)
- [🐛 Troubleshooting](#-troubleshooting)

## ✅ Prerequisites

### Required Tools
- Terraform v1.0+
- Azure CLI installed and authenticated (`az login`)
- PowerShell 7+ (for automation scripts)
- Git for version control

### Azure Permissions
- Contributor on subscription or resource group
- User Access Administrator (for role assignments)
- Ability to create network resources
- Access to manage Azure AD joined devices (if using Intune)

### Planning Requirements
- VNET address space allocation
- DevBox user groups identified
- Compliance and security requirements documented
- Intune configuration ready (optional)

## 🚀 Quick Start

### Step 1: Clone Repository

```powershell
git clone <infrastructure-repo-url>
cd infrastructure
```

### Step 2: Configure Variables

```powershell
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
resource_group_name = "rg-devbox-infrastructure"
location            = "eastus"
user_principal_id   = "<your-user-object-id>"

# Network configuration
vnet_address_space     = ["10.4.0.0/16"]
subnet_address_prefix  = "10.4.0.0/24"
enable_nat_gateway     = true

# DevCenter configuration
devcenter_name = "devcenter-prod"
project_name   = "devbox-project"
gallery_name   = "galdevbox"
```

### Step 3: Deploy Infrastructure

```powershell
.\scripts\01-deploy-infrastructure.ps1
```

This deploys:
- Resource Group
- Virtual Network with NAT Gateway
- DevCenter and Project
- Network Connection (Azure AD Join)
- Azure Compute Gallery
- Managed Identity with permissions

### Step 4: Configure Network

```powershell
.\scripts\02-attach-networks.ps1
```

Waits for network health check and attaches connection to DevCenter.

### Step 5: Build Security Baseline Image

```powershell
cd ..\images\packer\base

# Configure variables
cp security-baseline.pkrvars.hcl.example security-baseline.pkrvars.hcl
# Edit with terraform outputs

# Create image definition (first time only)
.\create-image-definition.ps1

# Build baseline image
.\build-baseline-image.ps1 -ImageVersion "1.0.0"
```

### Step 6: Grant Team Access

```powershell
cd ..\..\infrastructure

# Get gallery resource ID
$galleryId = terraform output -raw gallery_id

# Grant Reader role to development teams
az role assignment create `
  --assignee <dev-team-group-id> `
  --role "Reader" `
  --scope $galleryId
```

### Step 7: Sync Pools (Ongoing)

When development teams update definitions:

```powershell
.\scripts\04-sync-pools.ps1
```

## 📁 Repository Structure

```
infrastructure/
├── main.tf                 # Core Terraform configuration
├── variables.tf            # Infrastructure variables
├── outputs.tf              # Infrastructure outputs
├── terraform.tfvars        # User-specific values (gitignored)
├── terraform.tfvars.example
│
├── modules/
│   ├── vnet/              # Virtual network module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   └── devcenter/         # DevCenter module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── scripts/
│   ├── 01-deploy-infrastructure.ps1   # Deploy core infrastructure
│   ├── 02-attach-networks.ps1         # Configure networks
│   ├── 03-configure-intune.ps1        # Intune configuration (optional)
│   └── 04-sync-pools.ps1              # Sync pools from definitions
│
├── policies/
│   └── compliance-settings.json       # Compliance policies
│
├── CODEOWNERS              # @operations-team owns infrastructure
└── README.md               # This file
```

### Key Infrastructure Resources

| Resource | Purpose | Managed By |
|----------|---------|------------|
| DevCenter | Central management hub | Operations |
| Project | Dev Box project configuration | Operations |
| Network Connection | Azure AD join, network config | Operations |
| Virtual Network | Network isolation | Network Team |
| Compute Gallery | Shared image storage | Operations |
| Managed Identity | DevCenter permissions | Operations |

## 👔 Operations Workflow

### Responsibilities

- ✅ Deploy and maintain core infrastructure
- ✅ Manage network configurations
- ✅ Configure Intune and compliance policies
- ✅ Build and version Security Baseline Images
- ✅ Approve infrastructure changes
- ✅ Sync DevBox pools when definitions change
- ✅ Monitor gallery and image versions
- ✅ Grant access to development teams

### Initial Deployment

#### 1. Deploy Infrastructure

```powershell
cd infrastructure

# Create and configure terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit with your values

# Deploy infrastructure
.\scripts\01-deploy-infrastructure.ps1
```

Creates:
- Resource Group
- Virtual Network (with NAT Gateway)
- DevCenter
- DevCenter Project
- Network Connection
- Azure Compute Gallery
- Managed Identity

#### 2. Network Configuration

```powershell
# Attach network connection to DevCenter
.\scripts\02-attach-networks.ps1
```

Waits for network health check (5-10 minutes) and attaches to DevCenter.

#### 3. Optional Intune Configuration

```powershell
# Get guidance for Intune setup
.\scripts\03-configure-intune.ps1
```

Provides checklist for:
- Azure AD automatic enrollment
- License requirements
- Intune policy configuration

#### 4. Build Security Baseline Image

**This is a critical step** - the baseline image must exist before developers can build team images.

```powershell
cd ..\images\packer\base

# Create and configure security-baseline.pkrvars.hcl
cp security-baseline.pkrvars.hcl.example security-baseline.pkrvars.hcl
# Edit with values from terraform output:
# - subscription_id
# - resource_group_name
# - gallery_name
# - location

# Create the image definition in the gallery (first time only)
.\create-image-definition.ps1

# Build the golden baseline image (version 1.0.0)
.\build-baseline-image.ps1 -ImageVersion "1.0.0"

# Or validate without building
.\build-baseline-image.ps1 -ImageVersion "1.0.0" -ValidateOnly

# For CI/CD (skip confirmations)
.\build-baseline-image.ps1 -ImageVersion "1.0.0" -Force
```

The `SecurityBaselineImage` contains:
- Windows hardening and security policies
- Compliance configurations
- Base tooling (Git, VS Code, etc.)
- Organization-wide settings
- Azure AD join readiness

**Build Time:** Approximately 45-60 minutes

**Development teams cannot build their images until this baseline exists.**

#### 5. Grant Development Team Access

```bash
# Get gallery resource ID
GALLERY_ID=$(terraform output -raw gallery_id)

# Grant Reader role to development teams
az role assignment create \
  --assignee <dev-team-group-id> \
  --role "Reader" \
  --scope $GALLERY_ID
```

Development teams need:
- Reader access to the Azure Compute Gallery
- Terraform outputs (subscription, resource group, gallery name)
- SecurityBaselineImage version number

#### 6. Ongoing - Sync Pools

When development teams add new definitions:

```powershell
# Read definitions from images repo and create pools
cd infrastructure\scripts
.\04-sync-pools.ps1
```

Or integrate with CI/CD to run automatically when definitions change.

### Terraform Outputs

The infrastructure deployment provides outputs for development teams:

```bash
terraform output

# Key outputs for Development Teams:
# - resource_group_name: Where gallery lives
# - gallery_name: Name of compute gallery  
# - subscription_id: Azure subscription (for Packer)
# - location: Azure region
# - gallery_id: Full resource ID (for permissions)
```

Share these values with development teams for their Packer variable files.

**Note:** `tenant_id` is not needed as Packer uses Azure CLI authentication (`az login`).

### Updating Security Baseline

When updating the baseline for new security requirements:

```powershell
# Edit images/packer/base/security-baseline.pkr.hcl
# Add new security configurations or tools

# Build new version
cd images\packer\base
.\build-baseline-image.ps1 -ImageVersion "1.1.0"

# Notify development teams to rebuild with new baseline
# They update their templates:
# baseline_image_version = "1.1.0"
```

Version changes:
- **Major (2.x.x)**: Breaking changes to security baseline
- **Minor (x.1.x)**: New security features or tools added
- **Patch (x.x.1)**: Bug fixes or minor updates

## 🔧 Network Configuration

### Network Planning

| Setting | Default | Purpose |
|---------|---------|---------|
| VNET Address Space | 10.4.0.0/16 | Overall network range |
| Subnet Address | 10.4.0.0/24 | DevBox subnet (254 IPs) |
| NAT Gateway | Enabled | Outbound connectivity for health checks |
| Domain Join Type | AzureADJoin | Required for Intune enrollment |

### Network Requirements

DevBox network connections require:
- ✅ Subnet with at least /27 (recommended /24)
- ✅ NAT Gateway for outbound connectivity
- ✅ No conflicting IP ranges with on-premises networks
- ✅ DNS resolution to Azure AD and Microsoft endpoints

### Firewall Requirements

If using Azure Firewall or network security groups:

**Required Endpoints:**
- `*.microsoft.com` (Azure AD, Intune)
- `*.windows.net` (Azure services)
- `*.office.com` (Microsoft 365 integration)
- `*.digicert.com` (Certificate validation)

### Modifying Network Configuration

```powershell
# Edit terraform.tfvars
vnet_address_space     = ["10.5.0.0/16"]  # New range
subnet_address_prefix  = "10.5.0.0/24"

# Preview changes
terraform plan

# Apply changes
terraform apply
```

**⚠️ Warning:** Changing network configuration may require:
- Re-attaching network connection
- Re-provisioning existing Dev Boxes
- Coordination with development teams

## 🔐 Security & Compliance

### Security Baseline Image

The `SecurityBaselineImage` is the **mandatory foundation** for all team images:

**Included Security Controls:**
- Windows Defender enabled and configured
- Windows Firewall enabled
- User Account Control (UAC) enabled
- Windows Update configured
- Azure AD join capability
- Secure boot and TPM 2.0 support
- Audit logging enabled

**Protected by CODEOWNERS:**
- Only Operations Team can modify `images/packer/base/`
- All changes require @operations-team approval
- Prevents accidental removal of security controls

### Intune Integration

Configure Intune for:
- Conditional Access policies
- Compliance policies
- Device configuration profiles
- Application deployment

**Setup Steps:**
1. Enable Azure AD automatic enrollment
2. Assign Intune licenses to users
3. Create device compliance policies
4. Configure conditional access rules
5. Test with pilot Dev Boxes

### Access Control

| Resource | Operations | Dev Leads | Developers |
|----------|-----------|-----------|------------|
| Infrastructure Terraform | Read/Write | Read | None |
| Network Configuration | Read/Write | Read | None |
| Compute Gallery | Owner | Reader | Reader |
| Security Baseline Image | Manage | None | None |
| DevCenter Project | Manage | Use | Use |

### Audit and Compliance

**Audit Logs:**
```powershell
# View DevCenter activity
az monitor activity-log list \
  --resource-group <rg> \
  --resource-type Microsoft.DevCenter/devcenters

# Check gallery access
az monitor activity-log list \
  --resource-group <rg> \
  --resource-type Microsoft.Compute/galleries
```

**Compliance Monitoring:**
- Review Terraform state for configuration drift
- Monitor image versions in gallery
- Track pool creation and updates
- Audit user access to Dev Boxes

## 📊 Monitoring & Maintenance

### Health Checks

**Network Connection:**
```powershell
# Check network connection status
az devcenter admin network-connection show \
  --name <connection-name> \
  --resource-group <rg> \
  --query healthCheckStatus

# Possible values: Pending, Running, Passed, Failed, Warning
```

**Compute Gallery:**
```bash
# List gallery images
az sig image-definition list \
  --gallery-name <gallery> \
  --resource-group <rg>

# Check specific image versions
az sig image-version list \
  --gallery-name <gallery> \
  --gallery-image-definition SecurityBaselineImage \
  --resource-group <rg>
```

**DevBox Pools:**
```bash
# List all pools
az devcenter admin pool list \
  --project <project> \
  --resource-group <rg>

# Check pool status
az devcenter admin pool show \
  --name <pool> \
  --project <project> \
  --resource-group <rg> \
  --query "{name:name, status:provisioningState, health:healthStatus}"
```

### Maintenance Tasks

**Monthly:**
- Review and rotate security baseline image (if needed)
- Check for Terraform provider updates
- Review Azure resource costs
- Audit user access and permissions

**Quarterly:**
- Review network capacity and subnet usage
- Update Terraform modules to latest versions
- Review and update compliance policies
- Test disaster recovery procedures

**As Needed:**
- Sync pools when definitions change
- Grant access to new development teams
- Update infrastructure for new requirements
- Scale resources based on usage

### Cost Management

**Monitor Costs:**
```powershell
# Get resource group costs
az consumption usage list \
  --start-date 2025-01-01 \
  --end-date 2025-01-31 \
  --query "[?contains(instanceName,'$RESOURCE_GROUP')]"
```

**Cost Optimization:**
- Use auto-stop schedules for Dev Box pools
- Right-size VM SKUs based on actual usage
- Remove unused gallery image versions
- Use Standard_LRS storage for gallery images

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/infrastructure.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'scripts/**'
  pull_request:

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Terraform Init
        run: terraform init
      
      - name: Terraform Validate
        run: terraform validate
      
      - name: Terraform Plan
        run: terraform plan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        run: terraform apply -auto-approve
```

### Security Baseline CI/CD

```yaml
# .github/workflows/build-baseline.yml
name: Build Security Baseline Image

on:
  push:
    branches: [main]
    paths:
      - 'images/packer/base/**'

jobs:
  build-baseline:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Packer
        uses: hashicorp/setup-packer@v2
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build Baseline Image
        run: |
          cd images/packer/base
          ./build-baseline-image.ps1 -ImageVersion "${{ github.run_number }}.0.0" -Force
```

## 🐛 Troubleshooting

### Network Connection Issues

**Problem: Health check fails**

```powershell
# Check network connection details
az devcenter admin network-connection show \
  --name <connection> \
  --resource-group <rg> \
  --query "{status:healthCheckStatus, details:healthCheckStatusDetails}"
```

**Common causes:**
- NAT Gateway not configured (`enable_nat_gateway = true`)
- Subnet too small (use at least /24)
- DNS resolution issues
- Firewall blocking required endpoints

**Solution:**
```powershell
# Update terraform.tfvars
enable_nat_gateway = true

# Reapply
terraform apply
```

### Gallery Issues

**Problem: Gallery not visible in DevCenter**

```powershell
# Verify gallery attachment
az devcenter admin gallery list \
  --dev-center <devcenter> \
  --resource-group <rg>

# Check managed identity permissions
az role assignment list \
  --assignee <managed-identity-principal-id> \
  --scope <gallery-resource-id>
```

**Solution:**
Grant managed identity the required role on gallery.

### User Access Issues

**Problem: Users can't provision Dev Boxes**

```powershell
# Verify role assignment
az role assignment list \
  --assignee <user-principal-id> \
  --scope <project-resource-id>
```

**Solution:**
```powershell
az role assignment create \
  --assignee <user-principal-id> \
  --role "DevCenter Dev Box User" \
  --scope <project-resource-id>
```

### Baseline Image Build Issues

**Problem: Packer build fails**

Check:
- Azure CLI authentication (`az account show`)
- Permissions on gallery (Contributor required)
- Variables file has correct values
- Image definition exists (`create-image-definition.ps1`)

**Problem: Build timeout**

Increase build VM size in `security-baseline.pkrvars.hcl`:
```hcl
vm_size = "Standard_D4s_v3"  # Faster than D2s_v3
```

## 📚 Additional Resources

### Microsoft Documentation
- [Microsoft DevCenter Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Azure Compute Galleries](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries)
- [DevBox Network Requirements](https://learn.microsoft.com/azure/dev-box/how-to-configure-network-connections)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### Best Practices
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [DevCenter Security Best Practices](https://learn.microsoft.com/azure/dev-box/concept-dev-box-security)

### Related Repositories
- **Images Repository**: Contains Packer templates for team-specific customizations
- Development teams build their images and manage definitions there

## 🤝 Contributing

### Pull Request Process
1. Create feature branch
2. Make changes to Terraform or scripts
3. Run `terraform fmt` and `terraform validate`
4. Create PR with description
5. Required approvals:
   - Operations Team member
   - Network Team (if network changes)
   - Security Team (if policy changes)
6. Merge to main triggers deployment

### Code Ownership (CODEOWNERS)

```
* @operations-team
/terraform/network*.tf @network-team @operations-team
/policies/ @security-team @operations-team
/images/packer/base/ @operations-team
```

## 🆘 Support

For issues or questions:
- Infrastructure issues: Contact @operations-team
- Network configuration: Contact @network-team
- Security policies: Contact @security-team
- General questions: Create GitHub issue

---

**Operations Team - Enabling Secure Development Environments! 🚀**
