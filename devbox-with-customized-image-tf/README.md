# DevBox with Customized Image - Terraform

This Terraform configuration converts the original Bicep templates to deploy Azure DevCenter with customized images using Terraform.

## Quick Start

```powershell
# Step 0: Deploy infrastructure
terraform init
terraform apply -var-file="terraform.tfvars" -auto-approve

# Step 1: Build images (30-60 min each)
cd packer
.\build-image.ps1 -ImageType windows -Action all
.\build-image.ps1 -ImageType intellij -Action all
cd ..

# Step 2: Create definitions
.\02-create-definitions.ps1

# Step 3: Create pools (also attaches network)
.\03-create-pools.ps1
```

## Overview

This configuration creates:

- Virtual Network and Subnet (optional, if not using existing subnet)
- Azure Compute Gallery with two customized image definitions
- Packer-built custom Windows images (VS Code focused and IntelliJ + WSL focused)
- User Assigned Managed Identity
- DevCenter with network connection
- DevCenter project with DevBox definitions and pools

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

4. **Customize image installation** in `modules/gallery/main.tf`:
   - Modify the `customized_commands` local variable
   - Add/remove software installations in the PowerShell commands

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

### Image Creation with Packer

This configuration now uses **Packer** instead of Azure Image Builder for creating custom images. This provides better infrastructure-as-code practices and more flexibility.

**Image Build Process**:

1. **Deploy Infrastructure**: Run Terraform to create the base resources
2. **Build Custom Image**: Use Packer to create the customized Windows image
3. **Manual DevCenter Setup**: Complete some DevCenter configuration manually

### DevCenter Resource Limitations

**Important**: Some DevCenter resources are not yet fully supported in the Terraform AzureRM provider (as of v3.117.1). This configuration automates workarounds for:

- DevCenter Attached Networks (automated in step 3)
- DevCenter Project Pools (automated in step 3)

### Complete Deployment Process

#### Step 0: Deploy Base Infrastructure

```powershell
# Initialize Terraform
terraform init

# Deploy infrastructure (creates gallery, DevCenter, network, etc.)
terraform apply -var-file="terraform.tfvars" -auto-approve
```

**What gets created:**

- Resource Group
- Virtual Network and Subnet
- Azure Compute Gallery with two image definitions (CustomizedImage, IntelliJDevImage)
- DevCenter with network connection
- DevCenter project
- User Assigned Managed Identity with necessary permissions

---

#### Step 1: Build Custom Images with Packer

**Why:** The gallery image definitions are empty until Packer builds and publishes image versions.

```powershell
cd packer

# Copy and customize variables for both images
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
cp intellij-variables.pkrvars.hcl.example intellij-variables.pkrvars.hcl

# Edit the .pkrvars.hcl files with your values
# Then build both images (takes 30-60 minutes each)

# Build VS Code focused image
.\build-image.ps1 -ImageType windows -Action all

# Build IntelliJ + WSL image
.\build-image.ps1 -ImageType intellij -Action all

cd ..
```

**What gets built:**

- **CustomizedImage**: Windows 11 with VS Code, Git, Azure CLI, Node.js, Python
- **IntelliJDevImage**: Windows 11 with IntelliJ IDEA Community, WSL2, Java, Maven

---

#### Step 2: Create DevBox Definitions

**Why:** DevBox definitions link the custom images to compute SKUs and storage sizes.

```powershell
# Run the automated script
.\02-create-definitions.ps1
```

This script reads your Terraform state and `devcenter-settings.json` to create DevBox definitions using the DevCenter gallery images.

**Creates:**

- `win11-vs2022-vscode-openai` (CustomizedImage, 8c-32gb, 256GB SSD)
- `win11-intellij-wsl-dev` (IntelliJDevImage, 8c-32gb, 256GB SSD)

---

#### Step 3: Create DevBox Pools

**Why:** Pools allow users to provision Dev Boxes from the definitions. This step also attaches the network connection to the DevCenter.

```powershell
# Run the automated script - it will generate a personalized script
.\03-create-pools.ps1
```

This script:
1. Generates a personalized `create-pools.ps1` script with your specific values from Terraform state
2. Attaches the network connection to the DevCenter
3. Creates the Dev Box pools configured in `devcenter-settings.json`

**Note:** The generated `create-pools.ps1` is not tracked in git to keep your specific values private.

**Creates:**

- Network attachment to DevCenter
- `win11-vs2022-vscode-openai-pool`
- `win11-intellij-wsl-dev-pool`

---

#### Step 4: Access Your Dev Boxes

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

Modify the `customized_commands` in `modules/gallery/main.tf`:

```hcl
customized_commands = [
  {
    type = "PowerShell"
    name = "Install Custom Software"
    inline = [
      "# Add your custom installation commands here",
      "choco install -y your-package",
      "# Additional setup commands"
    ]
  }
]
```

### Changing Compute Sizes

Update the `compute` map in `modules/devcenter/main.tf` and corresponding settings in `devcenter-settings.json`.

## Outputs

After successful deployment, the configuration outputs:

- DevCenter name
- Project name  
- Network connection name
- Virtual network details (if created)
- DevBox definition and pool names

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
