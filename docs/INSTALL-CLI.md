# Installation Guide: CLI Deployment

This guide walks you through deploying DevBox infrastructure using **local Terraform CLI**. This approach is ideal for proof-of-concepts, small teams, or environments without CI/CD pipelines.

## When to Use CLI Deployment

**Choose this method if:**

- ✅ Proof-of-concept or testing
- ✅ Small team (1-5 people)
- ✅ Manual deployment is acceptable
- ✅ No CI/CD pipeline available
- ✅ Quick setup needed

**Consider Azure DevOps + TFE if:**

- ❌ Production environment
- ❌ Multiple teams collaborating
- ❌ Need audit trail and approval workflows
- ❌ Want automated deployments
- ❌ Enterprise governance required

## Prerequisites

- Azure subscription with Owner or Contributor + User Access Administrator
- Azure CLI installed and authenticated (`az login`)
- Terraform v1.0+ installed
- PowerShell 7+ (for automation scripts)
- Packer v1.9+ (for image building)

## Installation Steps

### Step 1: Clone Repository

```powershell
git clone https://github.com/your-org/microsoft.devcenter.git
cd microsoft.devcenter
```

### Step 2: Configure Infrastructure Variables

```powershell
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Basic Configuration
resource_group_name = "rg-devbox-prod"
location           = "eastus"
environment        = "prod"

# User/Group Configuration
user_principal_id = "00000000-0000-0000-0000-000000000000"  # Your Azure AD user ID

# Network Configuration
vnet_address_space    = ["10.4.0.0/16"]
subnet_address_prefix = ["10.4.0.0/24"]
enable_nat_gateway   = true

# DevCenter Configuration
devcenter_name = "dc-mycompany"
project_name   = "devbox-project"
gallery_name   = "galdevbox"

# Tags
tags = {
  Environment = "Production"
  ManagedBy   = "Terraform"
  CostCenter  = "Engineering"
}
```

**Get your user principal ID:**

```powershell
az ad signed-in-user show --query id -o tsv
```

### Step 3: Deploy Infrastructure

```powershell
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply
```

**Expected Resources Created:**

- Resource Group
- Virtual Network with NAT Gateway
- DevCenter and Project
- Network Connection (Azure AD join)
- Azure Compute Gallery
- Managed Identity

**Deployment time:** ~10-15 minutes

### Step 4: Attach Network Connection

```powershell
# Run automated script
.\scripts\02-attach-networks.ps1
```

This script:

1. Waits for network health check to pass (5-10 minutes)
2. Attaches network connection to DevCenter
3. Verifies attachment successful

**Manual alternative:**

```powershell
# Check health status
az devcenter admin network-connection show \
  --name <connection-name> \
  --resource-group <rg> \
  --query healthCheckStatus

# Once "Passed", attach to DevCenter
az devcenter admin attached-network list-by-dev-center \
  --dev-center-name <devcenter> \
  --resource-group <rg>
```

### Step 5: Build Security Baseline Image

The baseline image provides mandatory security configurations for all Dev Boxes.

```powershell
cd ..\images\packer\base
cp security-baseline.pkrvars.hcl.example security-baseline.pkrvars.hcl
```

Edit `security-baseline.pkrvars.hcl` with values from Terraform outputs:

```hcl
subscription_id         = "00000000-0000-0000-0000-000000000000"
resource_group_name     = "rg-devbox-prod"
gallery_name            = "galdevbox"
location                = "eastus"
image_version           = "1.0.0"
vm_size                 = "Standard_D2s_v3"
build_resource_group_name = "rg-packer-baseline-build"
```

**Get Terraform outputs:**

```powershell
cd ..\..\..\infrastructure
terraform output
```

**Create image definition (first time only):**

```powershell
cd ..\images\packer\base
.\create-image-definition.ps1
```

**Build baseline image:**

```powershell
# Prevent computer sleep during build (30-60 min)
powercfg /change standby-timeout-ac 0

# Build image
.\build-baseline-image.ps1 -ImageVersion "1.0.0"

# Re-enable sleep
powercfg /change standby-timeout-ac 15
```

**Validate only (no build):**

```powershell
.\build-baseline-image.ps1 -ImageVersion "1.0.0" -ValidateOnly
```

### Step 6: Grant Development Team Access

```powershell
# Get gallery resource ID
$galleryId = terraform output -raw gallery_id

# Grant Reader role to development team
az role assignment create \
  --assignee <dev-team-group-id> \
  --role "Reader" \
  --scope $galleryId
```

**Get group/user IDs:**

```powershell
# For user
az ad user show --id user@company.com --query id -o tsv

# For group
az ad group show --group "DevBox Users" --query id -o tsv
```

### Step 7: Build Team-Specific Images

Development teams can now build their custom images.

**Example: Java Team Image**

```powershell
cd ..\teams
cp java-variables.pkrvars.hcl.example java-variables.pkrvars.hcl
```

Edit `java-variables.pkrvars.hcl`:

```hcl
subscription_id         = "00000000-0000-0000-0000-000000000000"
resource_group_name     = "rg-devbox-prod"
gallery_name            = "galdevbox"
baseline_image_version  = "1.0.0"
image_version           = "1.0.0"
location                = "eastus"
vm_size                 = "Standard_D2s_v3"
build_resource_group_name = "rg-packer-java-build"
```

**Build image:**

```powershell
cd ..
.\build-image.ps1 -ImageType java
```

**Repeat for other teams:**

```powershell
.\build-image.ps1 -ImageType vscode
.\build-image.ps1 -ImageType dotnet
```

### Step 8: Configure DevBox Definitions

Edit `images/definitions/devbox-definitions.json`:

```json
{
  "definitions": [
    {
      "name": "Java-DevBox",
      "imageName": "JavaDevImage",
      "imageVersion": "1.0.0",
      "computeSku": "general_i_16c64gb512ssd_v2",
      "storageType": "ssd_512gb",
      "hibernationSupport": "Disabled",
      "team": "java-team",
      "description": "Java development with IntelliJ IDEA"
    },
    {
      "name": "VSCode-DevBox",
      "imageName": "VSCodeDevImage",
      "imageVersion": "1.0.0",
      "computeSku": "general_i_8c32gb256ssd_v2",
      "storageType": "ssd_256gb",
      "hibernationSupport": "Disabled",
      "team": "vscode-team",
      "description": "VS Code with Node.js, Python, Docker"
    }
  ],
  "pools": [
    {
      "name": "Java-Development-Pool",
      "definitionName": "Java-DevBox",
      "administrator": "Enabled",
      "schedule": {
        "time": "17:00",
        "timeZone": "Eastern Standard Time"
      }
    },
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

### Step 9: Create Definitions and Pools

```powershell
cd ..\..\infrastructure\scripts

# Validate configuration
.\00-validate-definitions.ps1

# Create definitions
.\03-create-definitions.ps1

# Create pools
.\04-sync-pools.ps1
```

### Step 10: Assign User Access

```powershell
# Grant DevCenter Dev Box User role
$projectId = terraform output -raw project_id

az role assignment create \
  --assignee <user-or-group-id> \
  --role "DevCenter Dev Box User" \
  --scope $projectId
```

## Verification

### Verify Infrastructure

```powershell
# Check DevCenter
az devcenter admin dev-center show \
  --name <devcenter> \
  --resource-group <rg>

# Check network connection
az devcenter admin network-connection show \
  --name <connection> \
  --resource-group <rg> \
  --query healthCheckStatus

# Check gallery images
az sig image-definition list \
  --gallery-name <gallery> \
  --resource-group <rg>
```

### Verify Definitions and Pools

```powershell
# List definitions
az devcenter admin devbox-definition list \
  --dev-center-name <devcenter> \
  --resource-group <rg>

# List pools
az devcenter admin pool list \
  --project <project> \
  --resource-group <rg>
```

### Test Dev Box Provisioning

1. Navigate to [Azure Dev Portal](https://devportal.microsoft.com/)
2. Sign in with your Azure AD account
3. Click "New" → "New Dev Box"
4. Select your project and pool
5. Click "Create"
6. Wait 15-30 minutes for provisioning
7. Click "Connect" when ready

## Ongoing Operations

### Update Team Images

When developers update their images:

```powershell
# 1. Update version in Packer variables
# images/packer/teams/java-variables.pkrvars.hcl
# image_version = "1.0.1"

# 2. Build new image
cd images/packer
.\build-image.ps1 -ImageType java

# 3. Update definitions file
# images/definitions/devbox-definitions.json
# "imageVersion": "1.0.1"

# 4. Update definitions in Azure
cd ..\..\infrastructure\scripts
.\00-validate-definitions.ps1
.\03-create-definitions.ps1 -Update
```

### Update Infrastructure

```powershell
cd infrastructure

# 1. Modify terraform files or variables
# 2. Preview changes
terraform plan

# 3. Apply changes
terraform apply
```

### Monitor Costs

```powershell
# View current month costs for resource group
az consumption usage list \
  --start-date $(Get-Date -Format "yyyy-MM-01") \
  --end-date $(Get-Date -Format "yyyy-MM-dd") \
  --query "[?contains(instanceId, 'rg-devbox-prod')]"
```

## Troubleshooting

### Network Health Check Fails

```powershell
# Verify NAT Gateway enabled
az network vnet show --name <vnet> --resource-group <rg> --query "subnets[0].natGateway"

# Check DNS resolution
nslookup microsoft.com

# Review network requirements
# https://learn.microsoft.com/azure/dev-box/how-to-configure-network-connections
```

### Image Build Failures

```powershell
# Enable detailed logging
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "packer.log"
.\build-image.ps1 -ImageType java

# Review logs
Get-Content packer.log | Select-String -Pattern "error|failed"

# Cleanup abandoned builds
az group list --query "[?starts_with(name, 'pkr-Resource-Group')].name" -o tsv
az group delete --name <build-rg> --yes --no-wait
```

### Definition Updates Not Reflecting

```powershell
# Definitions must be updated, not just pools
cd infrastructure/scripts
.\03-create-definitions.ps1 -Update

# Pools automatically reference updated definitions
```

## Next Steps

- **Set up Intune policies**: Run `.\scripts\03-configure-intune.ps1` for guidance
- **Configure RBAC**: Set up CODEOWNERS and branch protection
- **Plan backup strategy**: Consider gallery replication for DR
- **Monitor usage**: Set up Azure Monitor alerts for quota limits
- **Migrate to Azure DevOps + TFE**: See [INSTALL-ADO-TFE.md](INSTALL-ADO-TFE.md) for enterprise deployment

## Cleanup

To remove all resources:

```powershell
cd infrastructure

# Destroy all resources
terraform destroy

# Verify cleanup
az group show --name <rg>
```

**Warning:** This will delete all Dev Boxes, images, and infrastructure. Ensure data is backed up.

## Additional Resources

- [Main README](../README.md)
- [Azure DevOps + TFE Installation](INSTALL-ADO-TFE.md)
- [Microsoft DevCenter Documentation](https://learn.microsoft.com/azure/dev-box/)
- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
