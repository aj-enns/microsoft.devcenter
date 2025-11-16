# DevBox with Customized Image - Terraform

This Terraform configuration converts the original Bicep templates to deploy Azure DevCenter with customized images using Terraform.

## Quick Start

### Option A: Deploy with Built-in Images (Fastest - Recommended for Testing)

```powershell
# Step 0: Configure for built-in images
# Edit devcenter-settings.json and set imageType: "default" for all definitions

# Step 1: Deploy infrastructure
terraform init
terraform apply -var-file="terraform.tfvars" -auto-approve

# Step 2: Create gallery, definitions, and attach to DevCenter
.\02-create-definitions.ps1

# Step 3: Create pools (also attaches network)
.\03-create-pools.ps1

# Users can now create Dev Boxes with built-in VS2022 images!
```

### Option B: Deploy with Custom Images

```powershell
# Step 1: Deploy infrastructure
terraform init
terraform apply -var-file="terraform.tfvars" -auto-approve

# Step 2: Create gallery and image definitions (without image versions)
.\02-create-definitions.ps1

# Step 3: Build custom images with Packer (30-60 min each)
cd packer
.\build-image.ps1 -ImageType vscode -Action all
.\build-image.ps1 -ImageType visualstudio -Action all
.\build-image.ps1 -ImageType intellij -Action all
cd ..

# Step 4: Update devcenter-settings.json to use custom images
# Change imageType to "VSCodeImage", "VisualStudioImage", or "IntelliJDevImage"

# Step 5: Re-run definitions script to use custom images
.\02-create-definitions.ps1

# Step 6: Create pools
.\03-create-pools.ps1

# Step 7 (OPTIONAL): Configure Intune enrollment
.\05-configure-intune.ps1
```

## Overview

This configuration creates:

- Virtual Network and Subnet (optional, if not using existing subnet)
- User Assigned Managed Identity  
- DevCenter with network connection
- DevCenter project

The following are created via PowerShell scripts:
- Azure Compute Gallery with image definitions (Step 2)
- DevBox definitions (Step 2)
- DevBox pools (Step 3)
- Optional: Packer-built custom Windows images (between Steps 2-5)
- Optional: Intune enrollment configuration for device management (Step 7)

## Prerequisites

1. **Terraform Installation**: Ensure Terraform is installed
   ```bash
   # Using winget on Windows
   winget install Hashicorp.Terraform
   ```

2. **Azure CLI**: Ensure you're logged in to Azure CLI
   ```bash
   az login
   ```

3. **Required Permissions**: Ensure you have the necessary permissions to create:
   - Resource Groups
   - Virtual Networks
   - Compute Galleries and Image Templates
   - DevCenter resources
   - Role assignments

## Configuration

1. **Copy and customize terraform.tfvars**:
   ```bash
   cp terraform.tfvars terraform.tfvars.local
   ```

2. **Update terraform.tfvars.local** with your specific values:
   ```hcl
   resource_group_name = "your-resource-group-name"
   user_principal_id   = "your-user-or-service-principal-id"
   user_principal_type = "User" # or "ServicePrincipal" or "Group"
   location           = "eastus"
   ```

3. **Customize DevCenter settings** in `devcenter-settings.json`:
   - Modify dev box definitions (compute sizes, names)
   - Adjust pool configurations
   - Change administrator settings
   - **Important**: Set `imageType` to control which images are used:
     - `"default"` - Uses built-in Visual Studio 2022 Enterprise image (no custom image build required)
     - `"VSCodeImage"` - Uses your custom VS Code-focused image (requires Packer build)
     - `"VisualStudioImage"` - Uses your custom Visual Studio 2022 + VS Code image (requires Packer build)
     - `"IntelliJDevImage"` - Uses your custom IntelliJ-focused image (requires Packer build)

4. **Customize image software** in Packer configuration files (optional, only if using custom images):
   - **VS Code image**: Edit `packer/vscode-devbox.pkr.hcl`
   - **Visual Studio image**: Edit `packer/visualstudio-devbox.pkr.hcl`
   - **IntelliJ image**: Edit `packer/intellij-devbox.pkr.hcl`
   - Add/remove software installations in the Chocolatey provisioner sections

## Deployment

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Validate the configuration**:
   ```bash
   terraform validate
   ```

3. **Plan the deployment**:
   ```bash
   terraform plan -var-file="terraform.tfvars.local"
   ```

4. **Apply the configuration**:
   ```bash
   terraform apply -var-file="terraform.tfvars.local" -auto-approve
   ```

## Important Notes

### Network Connectivity Requirements

**NAT Gateway for Outbound Connectivity**: This configuration includes a NAT Gateway by default to provide secure outbound internet connectivity. This is **required** for:
- Azure DevCenter network health checks
- Connectivity to Azure Active Directory
- Access to Windows 365 and DevCenter service endpoints
- Software updates and telemetry

The NAT Gateway is enabled by default (`enable_nat_gateway = true`). If you have an existing outbound connectivity solution (e.g., Azure Firewall), you can disable it by setting `enable_nat_gateway = false` in your `terraform.tfvars`.

**Important**: Without proper outbound connectivity, the network connection health check will fail, and you won't be able to create Dev Box pools.

### Image Creation with Packer

This configuration now uses **Packer** instead of Azure Image Builder for creating custom images. This provides better infrastructure-as-code practices and more flexibility.

**Image Build Process**:

1. **Deploy Infrastructure**: Run Terraform to create the base resources
2. **Build Custom Image**: Use Packer to create the customized Windows image (optional)
3. **Manual DevCenter Setup**: Complete some DevCenter configuration manually

**Deploying Without Custom Images:**

You can deploy the infrastructure and start using Dev Boxes immediately without building custom images:

1. Set `imageType: "default"` in `devcenter-settings.json` for all definitions
2. Run `terraform apply`
3. The DevCenter will use built-in Visual Studio 2022 Enterprise images
4. Build custom images later when needed and switch to them by updating `imageType`

This approach is useful for:
- Quick testing and validation
- Getting started without waiting for image builds (30-60 min per image)
- Phased rollout where you start with built-in images and migrate to custom images later

### DevCenter Resource Limitations

**Important**: Some DevCenter resources are not yet fully supported in the Terraform AzureRM provider (as of v3.117.1). This configuration automates workarounds for:

- DevCenter Attached Networks (automated in step 3)
- DevCenter Project Pools (automated in step 3)

### Complete Deployment Process

#### Step 0: Deploy Base Infrastructure

```powershell
# Initialize Terraform
terraform init

# Deploy infrastructure (DevCenter, network, identity)
terraform apply -var-file="terraform.tfvars" -auto-approve
```

**What gets created:**

- Resource Group
- Virtual Network and Subnet (with NAT Gateway for outbound connectivity)
- User Assigned Managed Identity with necessary permissions
- DevCenter with network connection
- DevCenter project

**Note:** The gallery, image definitions, DevBox definitions, and pools are created separately via PowerShell scripts (Steps 1 and 3), giving you more flexibility in managing images and configurations.

---

#### Step 1: Create Gallery and DevBox Definitions

**Why is this script needed?**

This script creates the Azure Compute Gallery, image definitions, attaches the gallery to DevCenter, and creates DevBox definitions. It consolidates all image-related setup in one place, making it easier to manage.

**What it does:**

```powershell
# Run the automated script
.\02-create-definitions.ps1
```

This script:
1. Creates an Azure Compute Gallery if it doesn't exist
2. Creates image definitions (VSCodeImage, VisualStudioImage, IntelliJDevImage) in the gallery
3. Attaches the gallery to the DevCenter
4. Creates DevBox definitions based on `devcenter-settings.json`
5. Supports both custom images and built-in VS2022 images (imageType: "default")

**Creates:**

- Azure Compute Gallery
- Image definitions (empty, ready for Packer to build versions)
- DevBox definitions linked to either custom images or built-in VS2022
- Project settings (max dev boxes per user)

---

#### Step 2: Build Custom Images with Packer (Optional)

**Why:** If you want custom images instead of built-in VS2022, build them with Packer. Skip this step if you configured `imageType: "default"` to use built-in images.

**Note:** The Packer variable files (`variables.pkrvars.hcl` and `intellij-variables.pkrvars.hcl`) are automatically generated by Step 1 with the correct values from your Terraform deployment.

```powershell
cd packer

# Build VS Code image (30-60 minutes)
.\build-image.ps1 -ImageType vscode -Action all

# Build Visual Studio 2022 + VS Code image (30-60 minutes)
.\build-image.ps1 -ImageType visualstudio -Action all

# Build IntelliJ + WSL image (30-60 minutes)
.\build-image.ps1 -ImageType intellij -Action all

# Or build all at once (90-180 minutes total)
.\build-image.ps1 -ImageType all -Action all

cd ..
```

**What gets built:**

- **VSCodeImage**: Windows 11 with VS Code, Git, Azure CLI, Node.js, Python, .NET SDK, Docker, Terraform
- **VisualStudioImage**: Windows 11 with Visual Studio 2022 Enterprise + VS Code, all dev tools from VSCodeImage
- **IntelliJDevImage**: Windows 11 with IntelliJ IDEA Community, WSL2, Java, Maven

**Alternative:** If you're using `imageType: "default"`, you can skip this step entirely and use the built-in Visual Studio 2022 Enterprise image that comes with Azure DevCenter.

---

#### Step 3: Create DevBox Pools

**Why:** Pools allow users to provision Dev Boxes from the definitions. This step also attaches the network connection to the DevCenter.

**Why is this script needed?**

DevBox pools are what users actually provision from. They combine definitions, networking, and regions. Similar to Step 2, the Terraform AzureRM provider doesn't fully support pool creation or network attachment yet, so we use this script as a workaround.

**What it does:**

```powershell
# Run the automated script - it will generate a personalized script
.\03-create-pools.ps1
```

This script:

1. Generates a personalized `create-pools.ps1` script with your specific values from Terraform state
2. **Attaches the network connection** to the DevCenter (critical - without this, Dev Boxes can't connect to Azure resources or domain join for Intune)
3. Creates the Dev Box pools configured in `devcenter-settings.json`
4. Configures each pool with:
   - The region (e.g., westus2)
   - The network connection (for Azure/on-premises connectivity)
   - Auto-stop schedule (default: 7 PM local time, timezone-aware)

**Note:** The generated `create-pools.ps1` is not tracked in git to keep your specific values private.

**Creates:**

- Network attachment to DevCenter
- `VS Code Development` pool
- `Visual Studio 2022 Development` pool
- `IntelliJ IDEA Development` pool

**Important:** This step MUST complete before users can create Dev Boxes. The network attachment is especially critical if you plan to use Intune (Step 4).

---

#### Step 4: Configure Intune Enrollment (OPTIONAL)

**Why is this script needed?**

This step is **completely optional**! Run this only if you want Dev Boxes to automatically enroll in Microsoft Intune for device management and compliance policies. This script validates your configuration and provides guidance - it doesn't make changes itself.

**What it does:**

```powershell
# Run the configuration checker
.\05-configure-intune.ps1

# Or skip certain checks
.\05-configure-intune.ps1 -SkipAADCheck
```

This script:

1. **Verifies Azure AD automatic MDM enrollment** is configured (required for automatic Intune enrollment)
2. **Checks network connection domain join type** is set to "AzureADJoin" (Intune requires Azure AD-joined devices)
3. **Validates Dev Center provisioning settings** allow custom network configurations
4. **Provides guidance** on Intune policy configuration and testing
5. **Reports validation results** with clear next steps if configuration is incorrect

**Prerequisites:**

- Azure AD Premium P1/P2 licenses
- Microsoft Intune licenses for users
- Global Administrator or Intune Administrator role

**Important Notes:**

- ✅ **No image changes required** - Intune enrollment happens during Dev Box provisioning, not in the image
- ✅ **Can be added later** - You can enable Intune months after initial deployment without rebuilding images
- ✅ **Infrastructure-level** - Controlled by network connection settings (Step 1) and Azure AD config, not Packer
- ⚠️ **Network attachment must be complete** - Run Step 3 first to attach the network connection to your Dev Center
- ⚠️ **Requires licenses** - Users must have Azure AD Premium and Intune licenses

**You can skip this if:**
- You don't have Intune licenses
- You don't need device management/compliance policies  
- You want to add Intune integration later

**Testing Intune Enrollment:**

After provisioning a Dev Box, connect to it and verify enrollment:

```powershell
dsregcmd /status
```

Look for:
```
AzureAdJoined : YES
MDMUrl : https://enrollment.manage.microsoft.com/...
```

**Configuring Intune Policies:**

Once enrolled, manage Dev Boxes via Microsoft Endpoint Manager (https://endpoint.microsoft.com):
- **Compliance Policies** - Require encryption, antivirus, etc.
- **Configuration Profiles** - Deploy settings and apps
- **Security Baselines** - Apply Microsoft security recommendations
- **Update Policies** - Manage Windows updates

---

#### Step 5: Access Your Dev Boxes

Users can now create Dev Boxes:

1. Navigate to <https://devbox.microsoft.com>
2. Select your project
3. Choose a pool
4. Create and connect to your Dev Box

### Networking Resource Group

The `networking_resource_group_name` parameter creates a separate resource group for networking resources managed by DevCenter. This is automatically named using the pattern: `ni-{connection-name}-{location}`.

### Role Assignments

The configuration automatically creates necessary role assignments:

- DevCenter Dev Box User role for the specified principal
- Gallery access roles for managed identities
- Image Builder permissions

## Customization

### Adding Software to the Image

Edit the Packer configuration files to add software via Chocolatey:

**For VS Code focused image** (`packer/vscode-devbox.pkr.hcl`):

```hcl
# Install development tools via Chocolatey
provisioner "powershell" {
  inline = [
    "Write-Output 'Installing development tools...'",
    "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
    "choco install -y git --params '/GitAndUnixToolsOnPath /NoAutoCrlf'",
    "choco install -y azure-cli",
    "choco install -y vscode",
    # Add your custom software here
    "choco install -y your-package"
  ]
  valid_exit_codes = [0, 3010]
}
```

**For IntelliJ focused image** (`packer/intellij-devbox.pkr.hcl`):

```hcl
# Install development tools via Chocolatey
provisioner "powershell" {
  inline = [
    "Write-Output 'Installing development tools...'",
    "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
    "choco install -y git --params '/GitAndUnixToolsOnPath /NoAutoCrlf'",
    # Add your custom software here
    "choco install -y your-package"
  ]
  valid_exit_codes = [0, 3010]
}
```

After editing, rebuild the image with:

```powershell
cd packer
.\build-image.ps1 -ImageType vscode -Action all         # For VS Code image
.\build-image.ps1 -ImageType visualstudio -Action all   # For Visual Studio image
.\build-image.ps1 -ImageType intellij -Action all       # For IntelliJ image
```

### Changing Compute Sizes

Update the `compute` settings in `devcenter-settings.json`, then re-run `02-create-definitions.ps1` to update the definitions with the new compute SKUs.

## Outputs

After successful deployment, the configuration outputs:

- DevCenter name
- Project name  
- Network connection name
- Virtual network name (if created by Terraform)
- Subnet name (if created by Terraform)

## Cleanup

To destroy all resources:

```bash
terraform destroy -var-file="terraform.tfvars.local" -auto-approve
```

## Differences from Bicep Version

1. **Image Build Trigger**: Manual process vs automatic deployment script
2. **JSON File Handling**: Uses Terraform's `jsondecode()` function
3. **Resource Naming**: Uses Terraform locals and functions
4. **Role Definitions**: Creates custom roles using Terraform resources
5. **Module Structure**: Organized into reusable Terraform modules

## Troubleshooting

### Common Issues

1. **Image Build Not Starting**: Manually trigger the build as shown above
2. **Permission Errors**: Ensure proper Azure permissions and role assignments
3. **Resource Naming Conflicts**: Adjust the `suffix` variable or resource names
4. **Network Connection Issues**: Verify subnet configuration and networking resource group

### Validation Commands

```bash
# Check Terraform configuration
terraform validate

# Check Azure resources
az devcenter admin devcenter list --resource-group "your-resource-group"
az devcenter admin project list --resource-group "your-resource-group"
```

## Support

For issues specific to:

- **Terraform**: Check Terraform documentation
- **Azure DevCenter**: Check Azure DevCenter documentation  
- **Packer**: Check Packer documentation
