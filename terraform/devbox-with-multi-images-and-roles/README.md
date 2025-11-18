# DevBox with Multi-Images and Role-Based Management

This solution demonstrates a **separation of duties** approach for managing Microsoft DevCenter with custom images. It separates infrastructure management (Operations Team) from image customization (Development Teams), enabling both teams to work independently while maintaining security and compliance.

## 🎯 Architecture Overview

This solution is organized into two main folders that would eventually become separate repositories:

```
devbox-with-multi-images-and-roles/
├── infrastructure/          # Operations Team - Infrastructure & Network
│   ├── terraform/          # Core infrastructure configuration
│   ├── modules/            # Reusable Terraform modules
│   ├── scripts/            # Automation scripts
│   └── policies/           # Compliance and security policies
│
└── images/                 # Development Teams - Custom Images
    ├── packer/
    │   ├── base/          # Operations-controlled base templates
    │   └── teams/         # Team-specific image customizations
    └── definitions/       # DevBox definitions managed by dev teams
```

### Repository Separation Benefits

| Concern | Infrastructure Repo | Images Repo |
|---------|-------------------|-------------|
| **Ownership** | Operations Team | Development Teams |
| **Controls** | Networks, security, compliance | Software, tools, configurations |
| **PR Approvals** | @operations-team, @network-team, @security-team | @dev-leads, @team-leads |
| **Update Frequency** | Quarterly or as needed | Weekly or continuous |
| **Azure Resources** | DevCenter, Networks, Galleries | Gallery Images, Definitions |

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Operations Team Guide](#operations-team-guide)
- [Development Team Guide](#development-team-guide)
- [Separation of Duties](#separation-of-duties)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

## ✅ Prerequisites

### Common Requirements
- Azure subscription with appropriate permissions
- Azure CLI installed and authenticated (`az login`)
- Git for version control

### Operations Team
- Terraform v1.0+
- Azure permissions:
  - Contributor on subscription or resource group
  - User Access Administrator (for role assignments)
- Network planning (VNET address spaces)

### Development Teams
- Packer v1.9+
- Azure CLI authentication
- Access to Azure Compute Gallery (granted by Operations)

## 🚀 Quick Start

### For Operations Team

1. **Deploy Infrastructure**
   ```powershell
   cd infrastructure
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   .\scripts\01-deploy-infrastructure.ps1
   ```

2. **Configure Network Connections**
   ```powershell
   .\scripts\02-attach-networks.ps1
   ```

3. **Grant Image Team Access**
   ```powershell
   # Grant Reader role on gallery to dev teams
   az role assignment create \
     --assignee <dev-team-group-id> \
     --role "Reader" \
     --scope <gallery-resource-id>
   ```

### For Development Teams

1. **Build Custom Image**
   ```powershell
   cd images/packer
   cp teams/vscode-variables.pkrvars.hcl.example teams/vscode-variables.pkrvars.hcl
   # Edit with your values
   .\build-image.ps1 -ImageType vscode
   ```

2. **Update Definitions**
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
     ]
   }
   ```

3. **Create Pull Request**
   - Operations team runs `04-sync-pools.ps1` to create pools
   - Or CI/CD automatically syncs pools on merge

## 📁 Repository Structure

### Infrastructure Repository (Operations Managed)

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
│   │   └── main.tf
│   └── devcenter/         # DevCenter module
│       └── main.tf
│
├── scripts/
│   ├── 01-deploy-infrastructure.ps1   # Deploy core infrastructure
│   ├── 02-attach-networks.ps1         # Configure networks
│   ├── 03-configure-intune.ps1        # Intune configuration (optional)
│   └── 04-sync-pools.ps1              # Sync pools from definitions
│
├── policies/
│   └── compliance-settings.json
│
└── CODEOWNERS              # @operations-team owns infrastructure
```

#### Key Infrastructure Resources

| Resource | Purpose | Managed By |
|----------|---------|------------|
| DevCenter | Central management hub | Operations |
| Project | Dev Box project configuration | Operations |
| Network Connection | Azure AD join, network config | Operations |
| Virtual Network | Network isolation | Network Team |
| Compute Gallery | Shared image storage | Operations |
| Managed Identity | DevCenter permissions | Operations |

### Images Repository (Development Teams Managed)

```
images/
├── packer/
│   ├── base/              # Operations-controlled base templates
│   │   ├── required-provisioners.hcl    # Mandatory security/compliance
│   │   └── windows-base.pkr.hcl         # Base Windows configuration
│   │
│   ├── teams/             # Team-specific customizations
│   │   ├── vscode-devbox.pkr.hcl
│   │   ├── vscode-variables.pkrvars.hcl
│   │   ├── java-devbox.pkr.hcl
│   │   └── dotnet-devbox.pkr.hcl
│   │
│   └── build-image.ps1    # Image build script
│
├── definitions/
│   └── devbox-definitions.json         # DevBox definitions and pools
│
└── CODEOWNERS             # Team-specific ownership
```

#### Base Templates (Operations Controlled)

The `base/` folder contains templates that **CANNOT be modified by development teams**. These ensure:

- ✅ Azure AD join capability
- ✅ Security baseline (Defender, Firewall)
- ✅ Compliance tools (Azure CLI, monitoring)
- ✅ Audit logging configuration
- ✅ Final compliance verification

**Why can't developers modify these?**
- Removing Azure AD configuration breaks Intune enrollment
- Disabling security tools violates compliance policies
- These settings are organizationally mandated

## 👔 Operations Team Guide

### Responsibilities

- Deploy and maintain core infrastructure
- Manage network configurations
- Configure Intune and compliance policies
- Approve infrastructure changes
- Sync DevBox pools when definitions change
- Monitor gallery and image versions

### Deployment Workflow

#### Step 1: Initial Infrastructure Deployment

```powershell
cd infrastructure

# Create and configure terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
# Edit with your values:
# - resource_group_name
# - user_principal_id
# - location
# - network settings

# Deploy infrastructure
.\scripts\01-deploy-infrastructure.ps1
```

This creates:
- Resource Group
- Virtual Network (with NAT Gateway)
- DevCenter
- DevCenter Project
- Network Connection
- Azure Compute Gallery
- Managed Identity

#### Step 2: Network Configuration

```powershell
# Attach network connection to DevCenter
.\scripts\02-attach-networks.ps1
```

Waits for network health check and attaches to DevCenter.

#### Step 3: Optional Intune Configuration

```powershell
# Get guidance for Intune setup
.\scripts\03-configure-intune.ps1
```

Provides checklist for:
- Azure AD automatic enrollment
- License requirements
- Intune policy configuration

#### Step 4: Grant Development Team Access

```bash
# Get gallery resource ID
GALLERY_ID=$(terraform output -raw gallery_id)

# Grant Reader role to development teams
az role assignment create \
  --assignee <dev-team-group-id> \
  --role "Reader" \
  --scope $GALLERY_ID
```

#### Step 5: Ongoing - Sync Pools

When development teams add new definitions:

```powershell
# Read definitions from images repo and create pools
.\scripts\04-sync-pools.ps1
```

Or integrate with CI/CD to run automatically.

### Terraform Outputs

The infrastructure deployment provides outputs for the image team:

```bash
terraform output

# Key outputs:
# - resource_group_name: Where gallery lives
# - gallery_name: Name of compute gallery
# - subscription_id: Azure subscription
# - tenant_id: Azure AD tenant
# - location: Azure region
```

Development teams need these values for their Packer builds.

### Network Planning

| Setting | Default | Purpose |
|---------|---------|---------|
| VNET Address Space | 10.4.0.0/16 | Overall network range |
| Subnet Address | 10.4.0.0/24 | DevBox subnet (254 IPs) |
| NAT Gateway | Enabled | Outbound connectivity for health checks |
| Domain Join Type | AzureADJoin | Required for Intune enrollment |

### Modifying Infrastructure

1. Update `terraform.tfvars` or `*.tf` files
2. Run `terraform plan` to preview changes
3. Create PR for review
4. After approval, run `terraform apply`

### Monitoring and Maintenance

**Health Checks:**
```bash
# Check network connection status
az devcenter admin network-connection show \
  --name <connection-name> \
  --resource-group <rg> \
  --query healthCheckStatus

# List gallery images
az sig image-definition list \
  --gallery-name <gallery> \
  --resource-group <rg>
```

**Pool Management:**
```bash
# List all pools
az devcenter admin pool list \
  --project <project> \
  --resource-group <rg>

# Check pool status
az devcenter admin pool show \
  --name <pool> \
  --project <project> \
  --resource-group <rg>
```

## 👨‍💻 Development Team Guide

### Responsibilities

- Build and maintain team-specific custom images
- Define DevBox configurations (CPU, memory, storage)
- Update software packages and tools
- Test images before releasing to production
- Maintain `devbox-definitions.json`

### Building Custom Images

#### Step 1: Create Variable File

```powershell
cd images/packer
cp teams/vscode-variables.pkrvars.hcl.example teams/vscode-variables.pkrvars.hcl
```

Edit with values from Operations Team's Terraform outputs:

```hcl
subscription_id = "..."
tenant_id      = "..."
resource_group_name = "rg-devbox-multi-roles"
gallery_name   = "galdevbox"
image_definition_name = "VSCodeDevImage"
location = "eastus"
image_version = "1.0.0"  # Increment for new versions
```

#### Step 2: Customize Packer Template

Edit your team's Packer file (e.g., `teams/vscode-devbox.pkr.hcl`):

```hcl
# Add your team's tools (Order: 10-99)
provisioner "powershell" {
  inline = [
    "choco install -y your-custom-tool",
    "# Configure your tool"
  ]
}
```

**Rules:**
- ✅ Can add software installations
- ✅ Can configure development tools
- ✅ Can create directories and shortcuts
- ❌ Cannot remove base provisioners (Order: 1-4)
- ❌ Cannot remove compliance check (Order: 100)
- ❌ Cannot disable Windows Defender or Firewall
- ❌ Cannot remove Azure AD join configuration

#### Step 3: Validate Template

```powershell
.\build-image.ps1 -ImageType vscode -ValidateOnly
```

#### Step 4: Build Image

```powershell
# Full build (30-60 minutes)
.\build-image.ps1 -ImageType vscode
```

The build process:
1. Creates temporary VM in Azure
2. Applies base provisioners (Operations-controlled)
3. Applies your team customizations
4. Runs compliance verification
5. Generalizes (sysprep) the image
6. Uploads to Azure Compute Gallery

#### Step 5: Update Definitions

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

#### Step 6: Create Pull Request

1. Commit changes to branch
2. Create PR
3. Request review from team leads
4. After merge, Operations team syncs pools

### DevBox Compute SKUs

| SKU | vCPUs | RAM | Storage | Use Case |
|-----|-------|-----|---------|----------|
| `general_i_8c32gb256ssd_v2` | 8 | 32 GB | 256 GB | Web dev, scripting |
| `general_i_16c64gb512ssd_v2` | 16 | 64 GB | 512 GB | Java, large projects |
| `general_i_32c128gb1024ssd_v2` | 32 | 128 GB | 1 TB | ML, data science |

### Image Versioning

**Semantic Versioning Recommended:**
- `1.0.0` - Initial release
- `1.0.1` - Patch (minor fixes, security updates)
- `1.1.0` - Minor (new tools, non-breaking changes)
- `2.0.0` - Major (breaking changes, major upgrades)

Update `image_version` in your variables file for each build.

### Testing Images

Before releasing to production:

1. **Create test definition** with your new image version
2. **Provision test Dev Box** from test pool
3. **Verify:**
   - All tools installed correctly
   - Azure AD join successful (`dsregcmd /status`)
   - Intune enrollment successful
   - Compliance policies applied
4. **Update production definitions** after testing

### Common Software Installations

```powershell
# Package managers
choco install -y chocolatey
choco install -y winget

# Development tools
choco install -y git
choco install -y vscode
choco install -y visualstudio2022enterprise
choco install -y jetbrains-rider

# Languages and runtimes
choco install -y nodejs
choco install -y python
choco install -y dotnet-sdk
choco install -y openjdk
choco install -y golang

# Containers and orchestration
choco install -y docker-desktop
choco install -y kubernetes-cli
choco install -y kubernetes-helm

# Cloud tools
choco install -y azure-cli
choco install -y awscli
choco install -y terraform

# Databases
choco install -y postgresql
choco install -y mongodb
choco install -y redis
choco install -y azure-data-studio
```

## 🔒 Separation of Duties

### Code Ownership (CODEOWNERS)

#### Infrastructure Repository
```
* @operations-team
/terraform/network*.tf @network-team @operations-team
/policies/ @security-team @operations-team
```

#### Images Repository
```
/packer/base/ @operations-team
/packer/teams/vscode* @vscode-team-leads
/packer/teams/java* @java-team-leads
/definitions/ @dev-leads @operations-team
```

### Pull Request Workflow

#### Infrastructure Changes
1. Developer creates PR
2. **Required approvals:**
   - Operations Team member
   - Network Team (if network changes)
   - Security Team (if policy changes)
3. Automated checks:
   - `terraform fmt` validation
   - `terraform validate`
   - Security scanning
4. Merge to main → Terraform apply (manual or automated)

#### Image Changes
1. Developer creates PR
2. **Required approvals:**
   - Team Lead
   - Operations Team (notified, not required)
3. Automated checks:
   - `packer validate`
   - Compliance check (base provisioners present)
   - Security scanning
4. Merge to main → Trigger image build
5. On success → Update definitions
6. Operations script syncs pools

### Access Control

| Resource | Operations | Dev Leads | Developers |
|----------|-----------|-----------|------------|
| Infrastructure Terraform | Read/Write | Read | None |
| Network Configuration | Read/Write | Read | None |
| Compute Gallery | Owner | Reader | Reader |
| Gallery Images | Manage | Create | Create |
| DevBox Definitions | Review | Approve | Create |
| Base Packer Templates | Read/Write | Read | Read |
| Team Packer Templates | Review | Approve | Create |
| DevCenter Project | Manage | Use | Use |

### Why This Separation Matters

**Security & Compliance:**
- Operations ensures mandatory settings aren't bypassed
- Base templates prevent accidental removal of:
  - Azure AD join configuration
  - Security baseline (Defender, Firewall)
  - Audit logging
  - Compliance agents

**Developer Productivity:**
- Teams control their tooling without waiting for IT
- Self-service image builds
- Fast iteration on development environments
- Team-specific customization

**Operational Efficiency:**
- Clear ownership boundaries
- Reduced bottlenecks
- Automated pool synchronization
- Audit trail via Git history

## 🔄 CI/CD Integration

### GitHub Actions Example - Infrastructure

```yaml
# .github/workflows/infrastructure.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure/**'
  pull_request:
    paths:
      - 'infrastructure/**'

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      
      - name: Terraform Init
        working-directory: infrastructure
        run: terraform init
      
      - name: Terraform Validate
        working-directory: infrastructure
        run: terraform validate
      
      - name: Terraform Plan
        working-directory: infrastructure
        run: terraform plan
      
      - name: Terraform Apply
        if: github.ref == 'refs/heads/main'
        working-directory: infrastructure
        run: terraform apply -auto-approve
```

### GitHub Actions Example - Images

```yaml
# .github/workflows/build-images.yml
name: Build DevBox Images

on:
  push:
    branches: [main]
    paths:
      - 'images/packer/teams/**'
      - 'images/definitions/**'
  pull_request:
    paths:
      - 'images/**'

jobs:
  validate:
    runs-on: windows-latest
    strategy:
      matrix:
        image: [vscode, java, dotnet]
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Packer
        uses: hashicorp/setup-packer@v2
      
      - name: Packer Init
        working-directory: images/packer
        run: packer init teams/${{ matrix.image }}-devbox.pkr.hcl
      
      - name: Packer Validate
        working-directory: images/packer
        run: packer validate -var-file=teams/${{ matrix.image }}-variables.pkrvars.hcl teams/${{ matrix.image }}-devbox.pkr.hcl
      
      - name: Check Base Provisioners
        run: |
          # Verify base provisioners are included
          $file = "images/packer/teams/${{ matrix.image }}-devbox.pkr.hcl"
          $content = Get-Content $file -Raw
          
          $checks = @(
            "Azure AD Readiness",
            "Security Baseline",
            "Compliance Tools",
            "Final Compliance Check"
          )
          
          foreach ($check in $checks) {
            if (-not ($content -match $check)) {
              Write-Error "Missing required provisioner: $check"
              exit 1
            }
          }

  build:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: windows-latest
    strategy:
      matrix:
        image: [vscode]  # Build one at a time to avoid quota issues
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build Image
        working-directory: images/packer
        run: |
          packer build -var-file=teams/${{ matrix.image }}-variables.pkrvars.hcl teams/${{ matrix.image }}-devbox.pkr.hcl

  sync-pools:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Trigger Pool Sync
        run: |
          # Trigger webhook or run script in infrastructure repo
          curl -X POST ${{ secrets.POOL_SYNC_WEBHOOK }} \
            -H "Authorization: Bearer ${{ secrets.SYNC_TOKEN }}" \
            -d '{"definitions_updated": true}'
```

### Azure DevOps Pipelines Example

```yaml
# azure-pipelines-images.yml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - images/**

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
          
          - script: |
              cd images/packer
              packer init teams/vscode-devbox.pkr.hcl
              packer validate -var-file=teams/vscode-variables.pkrvars.hcl teams/vscode-devbox.pkr.hcl
            displayName: 'Validate Packer Template'
  
  - stage: Build
    condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
    jobs:
      - job: BuildImage
        steps:
          - task: AzureCLI@2
            inputs:
              azureSubscription: 'DevBox-ServiceConnection'
              scriptType: 'pscore'
              scriptLocation: 'inlineScript'
              inlineScript: |
                cd images/packer
                ./build-image.ps1 -ImageType vscode
```

## 🐛 Troubleshooting

### Infrastructure Issues

**Problem: Network connection health check fails**
```powershell
# Check network connection details
az devcenter admin network-connection show \
  --name <connection> \
  --resource-group <rg> \
  --query "{status:healthCheckStatus, details:healthCheckStatusDetails}"

# Common causes:
# - NAT Gateway not configured (enable_nat_gateway = true)
# - Subnet too small (use at least /24)
# - DNS resolution issues
# - Firewall blocking required endpoints
```

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

**Problem: Users can't provision Dev Boxes**
```powershell
# Verify role assignment
az role assignment list \
  --assignee <user-principal-id> \
  --scope <project-resource-id>

# Check project settings
az devcenter admin project show \
  --name <project> \
  --resource-group <rg>
```

### Image Build Issues

**Problem: Packer build fails authentication**
```powershell
# Verify Azure CLI login
az account show

# Check permissions on gallery
az role assignment list \
  --assignee <your-user-id> \
  --scope <gallery-resource-id>
```

**Problem: Base provisioners missing compliance**
```powershell
# Review build logs for compliance check output
# Look for "OPERATIONS TEAM PROVISIONER: Final Compliance Check"
# Check for warnings about disabled security features

# Common issues:
# - Windows Defender accidentally disabled
# - Firewall turned off
# - UAC disabled
```

**Problem: Image build times out**
```hcl
# Increase timeouts in Packer template
source "azure-arm" "..." {
  winrm_timeout = "30m"  # Increase from 5m
  build_resource_group_name = "packer-builds"  # Use dedicated RG
}

# Use larger VM size for faster builds
vm_size = "Standard_D4s_v3"  # Instead of D2s_v3
```

**Problem: Chocolatey installations fail**
```powershell
# In provisioner, add retry logic
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

### Pool Sync Issues

**Problem: Pools not creating automatically**
```powershell
# Manually run sync script
cd infrastructure/scripts
./04-sync-pools.ps1 -Verbose

# Check if definitions file is readable
Test-Path ../../images/definitions/devbox-definitions.json

# Verify DevBox definitions exist in DevCenter
az devcenter admin devbox-definition list \
  --dev-center <devcenter> \
  --resource-group <rg>
```

**Problem: Definition not found in DevCenter**
```
# Definition must be created first via Packer build
# Or create manually:
az devcenter admin devbox-definition create \
  --dev-center-name <devcenter> \
  --resource-group <rg> \
  --devbox-definition-name "VSCode-DevBox" \
  --image-reference id="<image-id>" \
  --sku name="general_i_8c32gb256ssd_v2" \
  --os-storage-type "ssd_256gb" \
  --location <location>
```

### DevBox Provisioning Issues

**Problem: Dev Box stuck in "Creating" state**
- Check network connection health
- Verify image exists in gallery
- Check quota limits for VM SKU
- Review Azure Activity Log for errors

**Problem: Can't connect to Dev Box via RDP**
- Verify network security group rules
- Check if user has "DevCenter Dev Box User" role
- Ensure RDP client is updated
- Try web-based connection from Dev Portal

**Problem: Intune not enrolling Dev Box**
```powershell
# On Dev Box, check Azure AD join status
dsregcmd /status

# Look for:
# AzureAdJoined : YES
# MDMUrl : https://enrollment.manage.microsoft.com/...

# If not enrolled:
# - Verify Azure AD automatic enrollment is configured
# - Check user has Intune license
# - Verify network connection domain join type is AzureADJoin
```

### Common Error Messages

| Error | Cause | Solution |
|-------|-------|----------|
| "Image not found in gallery" | Image build not complete or failed | Build image with Packer |
| "Network connection health check failed" | Network misconfiguration | Check NAT Gateway, DNS, firewall |
| "Insufficient quota for SKU" | VM quota limit reached | Request quota increase or use different SKU |
| "User does not have permission" | Missing role assignment | Grant "DevCenter Dev Box User" role |
| "Definition not found" | Definition not created in DevCenter | Run sync script or create definition |

## 📚 Additional Resources

### Microsoft Documentation
- [Microsoft DevCenter Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Azure Compute Galleries](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)

### DevCenter Specific
- [DevBox Network Requirements](https://learn.microsoft.com/azure/dev-box/how-to-configure-network-connections)
- [Custom Image Requirements](https://learn.microsoft.com/azure/dev-box/how-to-configure-dev-box-azure-image-builder)
- [Intune Integration](https://learn.microsoft.com/azure/dev-box/how-to-configure-intune-conditional-access-policies)

### Best Practices
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Packer Best Practices](https://www.packer.io/guides/packer-on-cicd)
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)

## 🤝 Contributing

### Development Teams
1. Fork/clone the images repository
2. Create feature branch (`git checkout -b feature/my-new-tool`)
3. Make changes to your team's Packer templates
4. Test image build locally
5. Update `devbox-definitions.json` if needed
6. Commit and push
7. Create Pull Request for team lead review

### Operations Team
1. Infrastructure changes follow similar process
2. Additional review from network/security teams
3. Test in non-production environment first
4. Plan maintenance windows for major changes

## 📝 License

This sample is provided as-is under the MIT License.

## 🆘 Support

For issues or questions:
- Infrastructure issues: Contact @operations-team
- Image build issues: Contact your team lead
- General questions: Check documentation or create GitHub issue

---

**Happy DevBox Building! 🚀**
