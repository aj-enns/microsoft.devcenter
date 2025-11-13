# Packer Integration for DevCenter Custom Images

This directory contains Packer configuration for building custom Windows images for Azure DevCenter. Using Packer provides better infrastructure-as-code practices compared to Azure Image Builder templates.

## Benefits of Using Packer

- ✅ **Infrastructure as Code**: Configuration is version-controlled and repeatable
- ✅ **Better Integration**: Works seamlessly with Terraform
- ✅ **Flexibility**: More customization options and provisioner types
- ✅ **Multi-cloud**: Can build images for multiple cloud providers
- ✅ **Community Support**: Large ecosystem of plugins and provisioners

## Prerequisites

1. **Install Packer**:
   ```powershell
   # Using Chocolatey
   choco install packer
   
   # Or download from https://www.packer.io/downloads
   ```

2. **Azure Authentication**:
   ```powershell
   # Option 1: Azure CLI (recommended for development)
   az login
   
   # Option 2: Service Principal (recommended for CI/CD)
   $env:ARM_SUBSCRIPTION_ID = "your-subscription-id"
   $env:ARM_TENANT_ID = "your-tenant-id"
   $env:ARM_CLIENT_ID = "your-client-id"
   $env:ARM_CLIENT_SECRET = "your-client-secret"
   ```

3. **Create Variables File**:
   ```powershell
   # Copy and customize the variables file
   Copy-Item variables.pkrvars.hcl.example variables.pkrvars.hcl
   # Edit variables.pkrvars.hcl with your specific values
   ```

## Quick Start

1. **Navigate to packer directory**:
   ```powershell
   cd packer
   ```

2. **Build the image**:
   ```powershell
   # Using the build script (recommended)
   .\build-image.ps1 -Action all
   
   # Or manually
   packer init .
   packer validate -var-file="variables.pkrvars.hcl" .
   packer build -var-file="variables.pkrvars.hcl" .
   ```

3. **Monitor progress**: The build typically takes 30-60 minutes

## Image Configuration

The Packer configuration (`windows-devbox.pkr.hcl`) includes:

### Base Image
- **OS**: Windows 11 Enterprise with Microsoft 365 Apps
- **Publisher**: MicrosoftWindowsDesktop  
- **Offer**: windows-ent-cpc
- **SKU**: win11-22h2-ent-cpc-m365

### Installed Software
- **Package Manager**: Chocolatey
- **Development Tools**: 
  - Git
  - Azure CLI
  - Visual Studio Code
  - Node.js
  - Python
  - .NET SDK
  - Docker Desktop
  - Terraform
  - Kubernetes CLI

### VS Code Extensions
- GitHub Copilot
- Azure Account
- Azure Resource Groups
- Python
- C# Dev Kit
- HashiCorp Terraform

### System Configuration
- Windows Defender exclusions for development folders
- Git global configuration
- PowerShell modules (Az, Microsoft.Graph, posh-git)
- Development directories (C:\dev, C:\repos, C:\workspace)
- Windows optional features (WSL, Hyper-V)

## Customization

### Adding Software
Edit the Chocolatey provisioner in `windows-devbox.pkr.hcl`:

```hcl
provisioner "powershell" {
  inline = [
    "choco install -y your-package",
    "choco install -y another-package"
  ]
}
```

### Adding VS Code Extensions
Modify the VS Code extensions provisioner:

```hcl
provisioner "powershell" {
  inline = [
    "& 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension your.extension --force"
  ]
}
```

### Custom Scripts
Add your own PowerShell provisioners:

```hcl
provisioner "powershell" {
  script = "scripts/custom-setup.ps1"
}
```

## Build Script Options

The `build-image.ps1` script supports several options:

```powershell
# Just validate the configuration
.\build-image.ps1 -Action validate

# Build in debug mode (interactive)
.\build-image.ps1 -Debug

# Force rebuild even if image exists
.\build-image.ps1 -Force

# Use custom variables file
.\build-image.ps1 -VarFile "prod.pkrvars.hcl"

# Full workflow: init, validate, build
.\build-image.ps1 -Action all
```

## Integration with Terraform

1. **Run Terraform first** to create the Compute Gallery and Image Definition:
   ```powershell
   cd ..  # Back to root directory
   terraform apply
   ```

2. **Then run Packer** to build the image:
   ```powershell
   cd packer
   .\build-image.ps1 -Action all
   ```

3. **Update DevCenter** to use the new image (happens automatically when image version is created)

## Versioning

Each Packer build creates a new image version. Update the `image_version` in your variables file:

```hcl
image_version = "1.1.0"  # Increment for new versions
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**:
   - Ensure `az login` is successful
   - Check environment variables for service principal auth
   - Verify permissions on resource group and gallery

2. **Build Failures**:
   - Use `-Debug` flag to get interactive access to build VM
   - Check Azure portal for build logs
   - Verify all required resources exist (gallery, image definition)

3. **Long Build Times**:
   - Comment out Windows Update provisioner for faster builds
   - Reduce the number of installed packages
   - Use smaller VM size for build

### Debug Mode

Run Packer in debug mode for interactive troubleshooting:

```powershell
.\build-image.ps1 -Debug
```

This allows you to:
- Step through each provisioner
- Connect to the build VM via RDP
- Debug installation issues interactively

## Best Practices

1. **Version Control**: Keep Packer configs in source control
2. **Parameterization**: Use variables for environment-specific values
3. **Testing**: Build and test images in development before production
4. **Documentation**: Document all customizations and their purposes
5. **Security**: Use service principals for automated builds
6. **Cleanup**: Packer automatically cleans up temporary resources

## Next Steps

After building your custom image:
1. The image version will be available in your Compute Gallery
2. DevCenter will automatically detect the new image version
3. Create new DevBox pools using the updated image
4. Test the DevBox to ensure all software is working correctly