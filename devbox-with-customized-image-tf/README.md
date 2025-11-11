# DevBox with Customized Image - Terraform

This Terraform configuration converts the original Bicep templates to deploy Azure DevCenter with customized images using Terraform.

## Overview

This configuration creates:
- Virtual Network and Subnet (optional, if not using existing subnet)
- Azure Compute Gallery with customized image definition 
- Azure Image Builder template for creating customized Windows images
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

**Important**: Some DevCenter resources are not yet fully supported in the Terraform AzureRM provider (as of v3.117.1). This configuration includes placeholders for these resources:

- DevCenter Attached Networks  
- DevCenter Project Pools

### Complete Deployment Process

1. **Deploy Base Infrastructure**:
   ```bash
   terraform init
   terraform apply -var-file="terraform.tfvars"
   ```

2. **Build Custom Image with Packer**:
   ```bash
   cd packer
   # Copy and customize variables
   cp variables.pkrvars.hcl.example variables.pkrvars.hcl
   # Build the image (takes 30-60 minutes)
   .\build-image.ps1 -Action all
   ```

3. **Complete DevCenter Setup** (Manual Steps):

   **Attach Network to DevCenter**:
   ```bash
   az devcenter admin attached-network create \
     --dev-center-name "your-devcenter-name" \
     --resource-group "your-resource-group" \
     --attached-network-connection-name "your-connection-name" \
     --network-connection-id "your-network-connection-id"
   ```

   **Create DevBox Pools**:
   ```bash
   az devcenter admin pool create \
     --project-name "your-project-name" \
     --resource-group "your-resource-group" \
     --pool-name "your-pool-name" \
     --devbox-definition-name "your-definition-name" \
     --network-connection-name "your-network-connection"
   ```

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
- **Azure Image Builder**: Check Azure Image Builder documentation