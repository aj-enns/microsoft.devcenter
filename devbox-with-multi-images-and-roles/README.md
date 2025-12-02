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

- [✅ Prerequisites](#-prerequisites)
- [🚀 Quick Start](#-quick-start)
- [📁 Repository Structure](#-repository-structure)
- [👔 Operations Team Guide](#-operations-team-guide)
- [💻 Development Team Guide](#-development-team-guide)
- [🔒 Separation of Duties](#-separation-of-duties)
- [🔄 CI/CD Integration](#-cicd-integration)
- [🐛 Troubleshooting](#-troubleshooting)

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
   cp teams/java-variables.pkrvars.hcl.example teams/java-variables.pkrvars.hcl
   # Edit with your values (subscription_id, gallery_name, etc.)
   
   # Optional: Enable Packer logging for troubleshooting
   $env:PACKER_LOG = "1"
   $env:PACKER_LOG_PATH = "java-packer.log"
   
   .\build-image.ps1 -ImageType java
   ```

2. **Update Image Version in Configuration**
   ```json
   // Edit images/definitions/devbox-definitions.json
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
          "description": "VS Code development environment with Node.js, Python, .NET"
        },
        {
          "name": "Java-DevBox",
          "imageName": "JavaDevImage",
          "imageVersion": "1.0.1",
          "computeSku": "general_i_8c32gb256ssd_v2",
          "storageType": "ssd_256gb",
          "hibernationSupport": "Disabled",
          "team": "java-team",
          "description": "Java development environment with IntelliJ IDEA"
        }
     ]
   }
   ```

3. **Validate Configuration (Optional but Recommended)**
   ```powershell
   cd ../../infrastructure/scripts
   
   # Pre-flight validation checks
   .\00-validate-definitions.ps1
   
   # Auto-fix common issues (storage type mismatches)
   .\00-validate-definitions.ps1 -Fix
   ```

4. **Update Definitions and Sync Pools**
   ```powershell
   # Update existing definitions to new image versions
   .\03-create-definitions.ps1 -Update
   
   # Verify pools are synced (usually no changes needed)
   .\04-sync-pools.ps1
   ```

5. **Create Pull Request**
   - Operations team reviews and merges
   - Or CI/CD automatically deploys on merge

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
│   ├── 00-validate-definitions.ps1    # Pre-flight validation (NEW)
│   ├── 01-deploy-infrastructure.ps1   # Deploy core infrastructure
│   ├── 02-attach-networks.ps1         # Configure networks
│   ├── 03-create-definitions.ps1      # Create/update DevBox definitions
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

#### Step 4: Build Security Baseline Image

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

This creates the `SecurityBaselineImage` with:
- Windows hardening and security policies
- Compliance configurations
- Base tooling (Git, VS Code, etc.)
- Organization-wide settings

**Note:** Development teams will reference this baseline image when building their team-specific images.

#### Step 5: Grant Development Team Access

```bash
# Get gallery resource ID
GALLERY_ID=$(terraform output -raw gallery_id)

# Grant Reader role to development teams
az role assignment create \
  --assignee <dev-team-group-id> \
  --role "Reader" \
  --scope $GALLERY_ID
```

#### Step 6: Ongoing - Manage Definitions and Pools

When development teams update images or definitions:

```powershell
cd infrastructure/scripts

# Option 1: Validate before deployment (recommended)
.\00-validate-definitions.ps1

# Option 2: Create new definitions or update existing ones
.\03-create-definitions.ps1          # Create new definitions only
.\03-create-definitions.ps1 -Update  # Update existing to new image versions

# Option 3: Sync pools (creates/updates pool configurations)
.\04-sync-pools.ps1
```

**Script Capabilities:**

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `00-validate-definitions.ps1` | Pre-flight checks | Before creating definitions |
| `00-validate-definitions.ps1 -Fix` | Auto-correct storage mismatches | When validation finds fixable issues |
| `03-create-definitions.ps1` | Create new definitions | First-time deployment |
| `03-create-definitions.ps1 -Update` | Update image versions | After building new image version |
| `04-sync-pools.ps1` | Create/update pools | After definition changes |

**Smart Features:**
- ✅ Scripts query Azure APIs dynamically (no hardcoded values)
- ✅ Auto-detect SKU storage requirements and suggest fixes
- ✅ Only update definitions when version changes detected
- ✅ Detailed error messages with exact fix commands

Or integrate with CI/CD to run automatically.

### Terraform Outputs

The infrastructure deployment provides outputs for the image team:

```bash
terraform output

# Key outputs for Development Teams:
# - resource_group_name: Where gallery lives
# - gallery_name: Name of compute gallery
# - subscription_id: Azure subscription (for Packer)
# - location: Azure region
```

Development teams need these values for their Packer variable files. Note: `tenant_id` is not needed as Packer uses Azure CLI authentication (`az login`).

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

## 💻 Development Team Guide

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
# Azure subscription where resources will be created
subscription_id = "00000000-0000-0000-0000-000000000000"

# Resource group containing the Azure Compute Gallery
resource_group_name = "rg-devbox-multi-roles"

# Name of the Azure Compute Gallery
gallery_name = "galdevbox"

# Version of SecurityBaselineImage to build from
baseline_image_version = "1.0.0"

# Version for this VS Code team image
image_version = "1.0.0"  # Increment for new versions

# Azure region for temporary build resources
location = "eastus"

# VM size for the build process
vm_size = "Standard_D2s_v3"

# Temporary resource group for Packer build (auto-created and deleted)
build_resource_group_name = "rg-packer-vscode-build"
```

**Note:** The image name (`VSCodeDevImage`) is predefined in the Packer template - you don't need to specify it.

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

# Optional: Enable detailed logging for troubleshooting
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "vscode-packer.log"
.\build-image.ps1 -ImageType vscode

# To disable logging
$env:PACKER_LOG = "0"
```

The build process:
1. Creates temporary VM in Azure
2. Applies base provisioners (Operations-controlled)
3. Applies your team customizations
4. Runs compliance verification
5. Generalizes (sysprep) the image
6. Uploads to Azure Compute Gallery

**Troubleshooting Builds:**

If builds fail, enable Packer logging to see detailed execution:

```powershell
# PowerShell
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "packer.log"
.\build-image.ps1 -ImageType java

# Check logs for errors
Get-Content packer.log | Select-String -Pattern "error|failed|exit code"
```

Common log patterns:
- **Exit code 50**: PowerShell syntax errors (often special characters like ✓, ⚠)
- **Exit code 1**: Provisioner failure (check command output in log)
- **WinRM timeout**: Network or VM size issues

**Preventing Build Interruptions:**

Packer builds take 30-60 minutes. To prevent failures from computer sleep:

```powershell
# Disable sleep temporarily
powercfg /change standby-timeout-ac 0
.\build-image.ps1 -ImageType java
powercfg /change standby-timeout-ac 15  # Re-enable after
```

#### Step 5: Update Definitions

Edit `definitions/devbox-definitions.json` to reference your new image version:

```json
{
  "definitions": [
    {
      "name": "VSCode-DevBox",
      "imageName": "VSCodeDevImage",
      "imageVersion": "1.0.1",  // Increment for each new build
      "computeSku": "general_i_8c32gb256ssd_v2",
      "storageType": "ssd_256gb",
      "hibernationSupport": "Disabled",
      "team": "vscode-team",
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

**Important Notes:**
- `imageVersion` must match the version you built with Packer
- `computeSku` storage size must be compatible with `storageType` (validation script will check)
- Use `ssd` (generic) for SKUs with specific storage sizes (e.g., `512ssd` in SKU name)
- Use `ssd_256gb`, `ssd_512gb` for SKUs without storage in the name

**Validate Configuration:**

```powershell
cd ../../infrastructure/scripts

# Check for issues before deployment
.\00-validate-definitions.ps1

# Auto-fix storage type mismatches
.\00-validate-definitions.ps1 -Fix
```

#### Step 6: Deploy Definition Update

```powershell
# Update existing definition to new image version
.\03-create-definitions.ps1 -Update
```

The script will:
- ✅ Detect that VSCode-DevBox exists with v1.0.0
- ✅ See that definitions file specifies v1.0.1  
- ✅ Update the definition to use the new image
- ⏭️ Skip definitions already at the correct version

Pools automatically reference the updated definition - no pool changes needed.

#### Step 7: Create Pull Request

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

**Update Workflow:**

1. **Increment version in Packer variables:**
   ```hcl
   // teams/java-variables.pkrvars.hcl
   image_version = "1.0.1"  // Was 1.0.0
   ```

2. **Build new image:**
   ```powershell
   .\build-image.ps1 -ImageType java
   ```

3. **Update definitions file:**
   ```json
   // definitions/devbox-definitions.json
   {
     "name": "Java-DevBox",
     "imageName": "JavaDevImage",
     "imageVersion": "1.0.1"  // Match Packer version
   }
   ```

4. **Deploy update:**
   ```powershell
   cd ../../infrastructure/scripts
   .\03-create-definitions.ps1 -Update  // Updates to new version
   ```

**Version Tracking:**
- Packer builds image with version → Gallery image tagged
- Definitions file references that version
- Scripts only update when versions differ
- Users get new image on next Dev Box provision

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

**Problem: Build fails with exit code 50**
```powershell
# Enable Packer logging to see details
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "packer.log"
.\build-image.ps1 -ImageType java

# Check logs for PowerShell syntax errors
Get-Content packer.log | Select-String -Pattern "exit code 50"

# Common cause: Special characters (✓, ⚠) in string interpolation
# Fix: Use string concatenation instead
# ❌ Write-Host "✓ Success: $variable"
# ✅ Write-Host ('Success: ' + $variable)
```

**Problem: Build interrupted (computer went to sleep)**
```powershell
# Packer builds take 30-60 minutes and need continuous connection
# Prevent sleep during build:
powercfg /change standby-timeout-ac 0  # Disable sleep on AC
.\build-image.ps1 -ImageType java
powercfg /change standby-timeout-ac 15  # Re-enable after

# Cleanup abandoned build resources
az group list --query "[?starts_with(name, 'pkr-Resource-Group')].name" -o tsv
az group delete --name <resource-group-name> --yes --no-wait
```

**Problem: WSL not fully installed in image**
```powershell
# Recent fix: Ensure wsl --update runs during build
# Check provisioner includes:
# wsl --update
# wsl --set-default-version 2
# wsl --install -d Ubuntu --web-download --no-launch

# Verify in log:
Get-Content packer.log | Select-String -Pattern "wsl --update|wsl --version"
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

### Definition and Pool Sync Issues

**Problem: Image version not updating in portal**
```powershell
# You need to UPDATE the definition, not just sync pools
# Pools show whatever version the definition references

cd infrastructure/scripts

# Update definition to new image version
.\03-create-definitions.ps1 -Update

# Pool automatically uses updated definition
```

**Problem: Can't delete definition (pool dependency)**
```powershell
# Must delete pool first, then definition
az devcenter admin pool delete \
  --name Java-Development-Pool \
  --project-name <project> \
  --resource-group <rg>

az devcenter admin devbox-definition delete \
  --name Java-DevBox \
  --dev-center-name <devcenter> \
  --resource-group <rg>

# Then recreate both
.\03-create-definitions.ps1
.\04-sync-pools.ps1
```

**Problem: SKU validation errors**
```powershell
# Use validation script to check before deployment
.\00-validate-definitions.ps1

# Common issues:
# - Storage type doesn't match SKU requirements
# - SKU name not found in Azure

# Auto-fix storage mismatches
.\00-validate-definitions.ps1 -Fix

# List valid SKUs
az devcenter admin sku list --query '[].name' -o table
```

**Problem: Pools not creating automatically**
```powershell
# Manually run sync script
cd infrastructure/scripts
.\04-sync-pools.ps1 -Verbose

# Check if definitions file is readable
Test-Path ../../images/definitions/devbox-definitions.json

# Verify DevBox definitions exist in DevCenter
az devcenter admin devbox-definition list \
  --dev-center <devcenter> \
  --resource-group <rg>
```

**Problem: Definition not found in DevCenter**
```powershell
# Definition must be created first
.\03-create-definitions.ps1

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
