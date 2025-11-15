# Terraform Examples for Azure Dev Box

This folder contains HashiCorp Terraform examples for deploying Azure Dev Box infrastructure with custom images.

## 📚 Available Examples

### 🎨 [devbox-with-customized-image](./devbox-with-customized-image/)

**Difficulty:** Intermediate to Advanced  
**Description:** Complete Dev Box deployment using Terraform for infrastructure and Packer for custom image building.

**What's included:**
- Azure Compute Gallery with multiple image definitions
- Dev Center with network connection
- Dev Center project with role assignments
- Virtual Network with NAT Gateway (optional)
- Packer configurations for building custom Windows images
- PowerShell scripts for definitions and pool creation
- Optional Intune integration configuration

**Three custom images:**
1. **VS Code Developer Image** - Windows 11 with VS Code, Git, Azure CLI, Node.js, Python, .NET SDK
2. **Visual Studio 2022 Developer Image** - Windows 11 with Visual Studio 2022, Git, Azure CLI, .NET SDK, Docker
3. **IntelliJ Developer Image** - Windows 11 with IntelliJ IDEA Community, WSL2, Java, Maven, Gradle

**Highlights:**
- ✅ Infrastructure as Code with Terraform
- ✅ Image building with Packer (more flexible than Azure Image Builder)
- ✅ Multiple image support (VS Code focused, IntelliJ focused)
- ✅ Automated deployment scripts
- ✅ Optional Intune device management integration
- ✅ NAT Gateway for secure outbound connectivity

**Deployment workflow:**
1. `terraform apply` - Creates infrastructure
2. `packer build` - Builds custom images (30-60 min each)
3. `02-create-definitions.ps1` - Creates DevBox definitions (initially bound to built-in images)
4. `03-create-pools.ps1` - Creates DevBox pools
5. `04-bind-custom-images.ps1` - Binds Dev Box definitions to Packer-built gallery images
6. `04-configure-intune.ps1` - (Optional) Configures Intune enrollment

[→ View Full Documentation](./devbox-with-customized-image/)

---

## 🚀 Why Use Terraform for Dev Box?

### Advantages

✅ **Multi-cloud skills** - Terraform knowledge transfers to other cloud providers  
✅ **Mature ecosystem** - Large community, extensive modules, proven tooling  
✅ **Flexible image building** - Packer provides more control than Azure Image Builder  
✅ **State management** - Track infrastructure changes over time  
✅ **Modularity** - Reusable modules for different environments  
✅ **CI/CD integration** - Works well with GitHub Actions, Azure DevOps, etc.  

### Considerations

⚠️ **State file management** - Requires remote backend for team collaboration  
⚠️ **Azure-specific syntax** - Less concise than Bicep for Azure-only deployments  
⚠️ **Provider updates** - May lag behind new Azure features  

---

## 🔧 Prerequisites

All Terraform examples require:

### Tools
- [Terraform](https://www.terraform.io/downloads) v1.0 or later
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) for authentication
- [Packer](https://www.packer.io/downloads) for image building
- [PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) 7+ (cross-platform)

### Azure Access
- Azure subscription with Contributor or Owner access
- Permissions to create:
  - Resource Groups
  - Virtual Networks
  - Compute Galleries and Image Templates
  - Dev Center resources
  - Role assignments

### Authentication
```bash
# Authenticate with Azure CLI
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Verify authentication
az account show
```

---

## 📖 Common Terraform Workflow

### 1. Initialize Terraform
```bash
cd devbox-with-customized-image
terraform init
```

### 2. Create Variables File
```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
code terraform.tfvars
```

### 3. Plan Deployment
```bash
terraform plan -var-file="terraform.tfvars"
```

### 4. Apply Infrastructure
```bash
terraform apply -var-file="terraform.tfvars"
```

### 5. Build Images with Packer
```bash
cd packer
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
# Edit variables file

# VS Code Dev Box image
.\build-image.ps1 -ImageType vscode -Action all

# Visual Studio 2022 Dev Box image
.\build-image.ps1 -ImageType visualstudio -Action all

# IntelliJ Dev Box image
.\build-image.ps1 -ImageType intellij -Action all
```

### 6. Complete DevBox Setup
```bash
cd ..
.\02-create-definitions.ps1
.\03-create-pools.ps1
.\u003c04-bind-custom-images.ps1
```

### 7. (Optional) Configure Intune
```bash
.\u003c04-configure-intune.ps1
```

### 8. Destroy Resources
```bash
terraform destroy -var-file="terraform.tfvars"
```

---

## 🎨 Customizing Images with Packer

### Why Packer?

Packer provides more flexibility than Azure Image Builder:

✅ **Reproducible builds** - Infrastructure as Code for images  
✅ **Version control** - Track image configuration changes  
✅ **Cross-platform** - Same tool for AWS, Azure, VMware, etc.  
✅ **Rich provisioners** - PowerShell, Bash, Ansible, Chef, etc.  
✅ **Local testing** - Build and test locally before cloud deployment  

### Adding Software to Images

Edit the Packer configuration files:

**For VS Code image** (`packer/windows-devbox.pkr.hcl`):
```hcl
provisioner "powershell" {
  inline = [
    "choco install -y your-package",
    "choco install -y another-package"
  ]
  valid_exit_codes = [0, 3010]
}
```

**For IntelliJ image** (`packer/intellij-devbox.pkr.hcl`):
```hcl
provisioner "powershell" {
  inline = [
    "choco install -y intellij-idea-community",
    "choco install -y your-java-tool"
  ]
  valid_exit_codes = [0, 3010]
}
```

After editing, rebuild the image:
```bash
cd packer
.\build-image.ps1 -ImageType visualstudio -Action all
```

---

## 🔐 Security Best Practices

### Terraform State
- **Use remote backend** (Azure Storage, Terraform Cloud, etc.)
- **Enable state locking** to prevent concurrent modifications
- **Encrypt state files** (sensitive data like connection strings)
- **Restrict access** to state storage

Example remote backend:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstate12345"
    container_name       = "tfstate"
    key                  = "devbox.tfstate"
  }
}
```

### Sensitive Variables
```hcl
variable "admin_password" {
  type      = string
  sensitive = true
}
```

### Network Security
- Enable NAT Gateway for controlled outbound access
- Use Network Security Groups (NSGs) for traffic filtering
- Consider Azure Firewall for advanced scenarios
- Enable network connection health checks

---

## 💰 Cost Optimization

### Terraform-specific tips:

1. **Use tags for cost tracking**
```hcl
tags = {
  Environment = "Dev"
  CostCenter  = "Engineering"
  ManagedBy   = "Terraform"
}
```

2. **Right-size resources**
- Start with smaller VM SKUs
- Monitor usage and adjust
- Use Terraform variables to easily change sizes

3. **Automation**
- Use `terraform destroy` for temporary environments
- Schedule creation/destruction with CI/CD
- Implement auto-shutdown policies

4. **Image management**
- Clean up old image versions
- Use shared galleries across subscriptions
- Monitor gallery storage costs

---

## 🐛 Common Issues & Solutions

### Issue: Terraform state locked
**Solution:** 
```bash
terraform force-unlock LOCK_ID
```

### Issue: Packer build fails with authentication error
**Solution:** Verify Azure CLI login: `az account show`

### Issue: Provider version conflicts
**Solution:** 
```bash
terraform init -upgrade
```

### Issue: DevBox pool creation fails (Step 3)
**Solution:** Ensure image versions exist in gallery, check network connection health

### Issue: Changes not applying
**Solution:** 
```bash
terraform refresh
terraform plan
```

---

## 📚 Terraform vs Bicep Comparison

| Feature | Terraform (This Folder) | Bicep |
|---------|------------------------|-------|
| **Image Building** | Packer (flexible, reusable) | Azure Image Builder (Azure-native) |
| **State Management** | State files (requires backend) | ARM (no state files) |
| **Modularity** | Terraform modules | Bicep modules |
| **Multi-cloud** | Yes | Azure only |
| **Syntax** | HCL | Bicep (JSON-like) |
| **Learning Curve** | Moderate | Easier for Azure devs |

**When to use Terraform:**
- Need multi-cloud capabilities
- Prefer Packer for image building
- Team has Terraform expertise
- Want infrastructure portability

**When to use Bicep:**
- Azure-only deployment
- Prefer simpler syntax
- Want Azure-native experience
- No state management needed

---

## 🔄 Migrating from Bicep

If you have existing Bicep-based Dev Box infrastructure:

1. **Export current state**
```bash
az deployment group show --resource-group your-rg --name your-deployment
```

2. **Import resources into Terraform**
```bash
terraform import azurerm_resource_group.main /subscriptions/{sub}/resourceGroups/{rg}
terraform import azurerm_dev_center.main /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DevCenter/devcenters/{name}
```

3. **Validate with plan**
```bash
terraform plan
```

4. **Test in non-production first**

---

## 🤝 Contributing

Have improvements or new Terraform examples? Contributions welcome!

1. Fork the repository
2. Create a feature branch
3. Add your Terraform configuration
4. Test thoroughly
5. Submit a pull request

---

## 📖 Additional Resources

- [Terraform Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure/arm)
- [Azure Dev Box with Terraform](https://learn.microsoft.com/azure/dev-box/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- [Packer Best Practices](https://www.packer.io/guides/packer-on-cicd)

---

## 💬 Questions?

Open an issue in the repository for questions, bugs, or feature requests.
