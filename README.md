# Deploying Dev Box with Separation of Duties using Terraform

A production-ready reference implementation for Microsoft DevCenter using **Terraform** with **separation of duties**. This solution separates infrastructure management (Operations Team) from image customization (Development Teams), enabling both teams to work independently while maintaining security and compliance.

## 🎯 What This Solution Provides

- ✅ **Infrastructure as Code**: Complete Terraform configuration for DevCenter, networks, and compute galleries
- ✅ **Separation of Duties**: Clear boundaries between operations (infrastructure) and developers (images)
- ✅ **Security Baseline**: Golden baseline image with mandatory security configurations
- ✅ **Team Customization**: Development teams build and manage their own tool-specific images
- ✅ **Automation Scripts**: PowerShell scripts for deployment, validation, and synchronization
- ✅ **Enterprise Integration**: Designed for Intune enrollment, Azure AD join, and compliance policies

## 📋 Architecture Overview

```
microsoft.devcenter/
├── infrastructure/          # Operations Team
│   ├── main.tf             # Core Terraform configuration
│   ├── modules/            # DevCenter & networking modules
│   ├── scripts/            # Deployment & sync automation
│   └── policies/           # Compliance settings
│
└── images/                 # Development Teams
    ├── packer/
    │   ├── base/          # Golden baseline (operations-controlled)
    │   └── teams/         # Team-specific customizations (Java, VS Code, .NET)
    └── definitions/       # DevBox definitions and pool configs
```

### Why Separation of Duties?

| Aspect | Infrastructure (Ops) | Images (Developers) |
|--------|---------------------|---------------------|
| **Ownership** | Operations, Network, Security teams | Development teams |
| **Manages** | DevCenter, VNets, galleries, baseline image | Software tools, team-specific images |
| **Update Frequency** | Quarterly or as needed | Weekly or continuous |
| **Access Control** | Restricted (3-tier approval) | Self-service (team lead approval) |
| **Security Boundary** | Enforces compliance baseline | Cannot modify baseline requirements |

## 📋 Table of Contents

- [Choose Your Deployment Method](#-choose-your-deployment-method)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Repository Structure](#repository-structure)
- [Operations Team Workflow](#operations-team-workflow)
- [Development Team Workflow](#development-team-workflow)
- [Separation of Duties](#separation-of-duties)
- [CI/CD Integration](#cicd-integration)
- [Troubleshooting](#troubleshooting)

## 🚀 Choose Your Deployment Method

This solution supports two deployment approaches:

### Option 1: CLI Deployment (Quick Start)

**Best for:** Proof-of-concepts, small teams, testing

- ⚡ Quick setup (15 minutes)
- 🔧 Manual deployment with local Terraform CLI
- 👤 Single administrator or small team
- 📝 No CI/CD pipeline required

**[→ Start with CLI Deployment](docs/INSTALL-CLI.md)**

### Option 2: Azure DevOps + Terraform Enterprise

**Best for:** Production environments, large organizations, enterprise governance

- 🏢 Multiple teams with separation of duties
- 🔄 Automated CI/CD pipelines
- ✅ Approval workflows and audit trails
- 💰 Cost estimation and policy checks
- 🔒 Service principal isolation
- 📊 Change tracking and rollback capabilities

**[→ Start with Azure DevOps + TFE](docs/INSTALL-ADO-TFE.md)**

### Quick Comparison

| Feature | CLI Deployment | Azure DevOps + TFE |
|---------|---------------|-------------------|
| **Setup Time** | 15 minutes | 1-2 hours |
| **Team Size** | 1-5 people | 5+ people |
| **Deployment** | Manual | Automated |
| **Approvals** | None | Multi-tier |
| **Cost Estimation** | Manual | Automatic |
| **Audit Trail** | Git history only | Full audit logs |
| **Rollback** | Manual | One-click |
| **Best For** | POC, Testing | Production, Enterprise |

## Prerequisites

**Common Requirements:**

- Azure subscription with appropriate permissions
- Azure CLI installed and authenticated (`az login`)
- Git for version control

**Operations Team:**

- Terraform v1.0+
- Azure permissions: Contributor + User Access Administrator
- Network planning (VNET address spaces)

**Development Teams:**

- Packer v1.9+
- Azure CLI authentication
- Reader access to Azure Compute Gallery (granted by Operations)

## Quick Start

**New to this solution?** Choose your deployment method above, then follow the detailed installation guide.

### CLI Deployment - 5 Steps

```powershell
# 1. Deploy infrastructure
cd infrastructure && terraform apply

# 2. Attach network connection
.\scripts\02-attach-networks.ps1

# 3. Build security baseline image
cd ..\images\packer\base
.\build-baseline-image.ps1 -ImageVersion "1.0.0"

# 4. Build team images
cd ..\teams
.\build-image.ps1 -ImageType java

# 5. Create definitions and pools
cd ..\..\infrastructure\scripts
.\03-create-definitions.ps1
.\04-sync-pools.ps1
```

**[→ Full CLI Installation Guide](docs/INSTALL-CLI.md)**

### Azure DevOps + TFE - Enterprise Setup

```powershell
# 1. Create service principals and TFE workspace
# 2. Set up two Azure DevOps repositories
# 3. Configure pipelines and variable groups
# 4. Deploy infrastructure via TFE
# 5. Build images via automated pipelines
```

**[→ Full Azure DevOps + TFE Guide](docs/INSTALL-ADO-TFE.md)**

## Repository Structure

### Infrastructure (Operations Team)

**Location:** `infrastructure/`

**Key Components:**

- **Terraform Configuration**: `main.tf`, `variables.tf`, `outputs.tf`
- **Modules**: Reusable components for DevCenter and networking
- **Scripts**: Automation for deployment, validation, and synchronization
  - `01-deploy-infrastructure.ps1` - Deploy core resources
  - `02-attach-networks.ps1` - Configure network connections
  - `03-create-definitions.ps1` - Create/update DevBox definitions
  - `04-sync-pools.ps1` - Synchronize pools with definitions
  - `00-validate-definitions.ps1` - Pre-flight validation

**Resources Managed:**

- DevCenter and Project
- Virtual Network with NAT Gateway
- Azure Compute Gallery
- Network Connection (Azure AD join)
- Managed Identity for DevCenter

### Images (Development Teams)

**Location:** `images/`

**Key Components:**

- **Base Templates** (`packer/base/`): Operations-controlled security baseline
  - Cannot be modified by development teams
  - Ensures Azure AD join, security hardening, compliance tools
- **Team Templates** (`packer/teams/`): Team-specific customizations
  - `vscode-devbox.pkr.hcl` - VS Code, Node.js, Python, Docker
  - `java-devbox.pkr.hcl` - Java, IntelliJ IDEA, Maven
  - Each team manages their own template
- **Definitions** (`definitions/devbox-definitions.json`):
  - DevBox configurations (SKU, storage, image version)
  - Pool settings (schedule, administrator mode)

**Business Logic:** The base templates enforce organizational security and compliance requirements that cannot be bypassed. Development teams get flexibility for tools and software while operations maintains control over security posture.

## Operations Team Workflow

### Initial Deployment

**1. Deploy Infrastructure with Terraform**

```powershell
cd infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your organization's values
.\scripts\01-deploy-infrastructure.ps1
```

Creates: DevCenter, Project, Network Connection, Virtual Network, Compute Gallery, Managed Identity

**2. Configure Network**

```powershell
.\scripts\02-attach-networks.ps1
```

**3. Build Security Baseline Image**

```powershell
cd ..\images\packer\base
cp security-baseline.pkrvars.hcl.example security-baseline.pkrvars.hcl
# Edit with values from terraform output
.\create-image-definition.ps1
.\build-baseline-image.ps1 -ImageVersion "1.0.0"
```

Creates the `SecurityBaselineImage` with Windows hardening, security policies, and base tooling that all team images must inherit.

**4. Grant Development Team Access**

```bash
az role assignment create \
  --assignee <dev-team-group-id> \
  --role "Reader" \
  --scope $(terraform output -raw gallery_id)
```

### Ongoing Management

**When development teams update images:**

```powershell
cd infrastructure/scripts

# Validate configuration
.\00-validate-definitions.ps1

# Update definitions to new image versions
.\03-create-definitions.ps1 -Update

# Sync pools (usually automatic)
.\04-sync-pools.ps1
```

**Key Scripts:**

- `00-validate-definitions.ps1` - Pre-flight checks (validates SKU/storage compatibility)
- `03-create-definitions.ps1 -Update` - Updates definitions when image versions change
- `04-sync-pools.ps1` - Creates/updates pools from definitions

**Monitoring:**

```bash
# Check network health
az devcenter admin network-connection show --name <name> --resource-group <rg> --query healthCheckStatus

# List gallery images
az sig image-definition list --gallery-name <gallery> --resource-group <rg>

# Check pools
az devcenter admin pool list --project <project> --resource-group <rg>
```

## Development Team Workflow

### Building Custom Images

**1. Configure Packer Variables**

Get values from Operations Team's Terraform outputs:

```powershell
cd images/packer/teams
cp java-variables.pkrvars.hcl.example java-variables.pkrvars.hcl
# Edit with: subscription_id, gallery_name, resource_group_name, baseline_image_version
```

**2. Customize Your Team's Template**

Edit `teams/java-devbox.pkr.hcl` to add your tools:

```hcl
provisioner "powershell" {
  inline = [
    "choco install -y your-custom-tool",
    "# Additional configuration"
  ]
}
```

**Rules:**

- ✅ Add software installations and configurations
- ❌ Cannot modify base provisioners (Azure AD, security baseline)
- ❌ Cannot disable Windows Defender or Firewall

**3. Build Image**

```powershell
cd ..
.\build-image.ps1 -ImageType java

# Troubleshooting: Enable detailed logging
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "java-packer.log"
.\build-image.ps1 -ImageType java
```

Build takes 30-60 minutes. Prevent computer sleep:

```powershell
powercfg /change standby-timeout-ac 0
.\build-image.ps1 -ImageType java
powercfg /change standby-timeout-ac 15  # Re-enable after
```

**4. Update Definitions**

Edit `definitions/devbox-definitions.json`:

```json
{
  "definitions": [
    {
      "name": "Java-DevBox",
      "imageName": "JavaDevImage",
      "imageVersion": "1.0.1",
      "computeSku": "general_i_16c64gb512ssd_v2",
      "storageType": "ssd_512gb"
    }
  ]
}
```

**5. Validate and Deploy**

```powershell
cd ../../infrastructure/scripts
.\00-validate-definitions.ps1           # Pre-flight checks
.\03-create-definitions.ps1 -Update     # Update to new image version
.\04-sync-pools.ps1                     # Sync pools (usually automatic)
```

### Image Versioning

Use semantic versioning:

- `1.0.0` - Initial release
- `1.0.1` - Patch (security updates, minor fixes)
- `1.1.0` - Minor (new tools, non-breaking changes)
- `2.0.0` - Major (breaking changes)

Update workflow:

1. Increment `image_version` in Packer variables
2. Build image with `build-image.ps1`
3. Update `imageVersion` in `devbox-definitions.json`
4. Run `03-create-definitions.ps1 -Update`

### Common Software Installations

```powershell
# Development tools
choco install -y git vscode visualstudio2022enterprise jetbrains-rider

# Languages
choco install -y nodejs python dotnet-sdk openjdk golang

# Containers & Cloud
choco install -y docker-desktop kubernetes-cli azure-cli terraform

# Databases
choco install -y postgresql mongodb redis azure-data-studio
```

### Testing Images

Before production release:

1. Provision test Dev Box from updated definition
2. Verify: tools installed, Azure AD joined, Intune enrolled
3. Run `dsregcmd /status` to confirm enrollment
4. Update production definitions after testing

## Separation of Duties

### Access Control Model

| Resource | Operations | Dev Teams |
|----------|-----------|-----------|
| Infrastructure (Terraform) | Read/Write | None |
| Network Configuration | Read/Write | None |
| Compute Gallery | Owner | Reader |
| Base Packer Templates | Read/Write | Read |
| Team Packer Templates | Review | Read/Write |
| DevBox Definitions | Review/Approve | Create |

### Code Ownership (CODEOWNERS)

**Infrastructure:**

```text
* @operations-team
/terraform/network*.tf @network-team @operations-team
/policies/ @security-team @operations-team
```

**Images:**

```text
/packer/base/ @operations-team
/packer/teams/vscode* @vscode-team-leads
/packer/teams/java* @java-team-leads
/definitions/ @dev-leads @operations-team
```

### Pull Request Workflow

**Infrastructure Changes:**

1. Create PR → 2. Require approvals (Operations, Network if needed, Security if policies) → 3. Automated validation (`terraform fmt`, `terraform validate`) → 4. Merge → 5. Deploy

**Image Changes:**

1. Create PR → 2. Require approval (Team Lead) → 3. Automated validation (`packer validate`, compliance checks) → 4. Merge → 5. Build image → 6. Operations updates definitions

### Business Reasoning

**Security & Compliance:** Operations enforces mandatory security configurations (Azure AD join, Defender, Firewall, audit logging) that cannot be bypassed by development teams.

**Developer Productivity:** Development teams have self-service image builds without waiting for IT approval, enabling fast iteration while maintaining security boundaries.

**Operational Efficiency:** Clear ownership reduces bottlenecks, Git provides audit trail, and automation ensures consistency.

## CI/CD Integration

For enterprise implementations, see detailed pipeline examples in `.azuredevops/`:

- **Terraform Enterprise Integration**: `infrastructure-repo/terraform-infrastructure.yml`
- **Image Build Pipelines**: `images-repo/build-team-images.yml`
- **Pool Synchronization**: `images-repo/sync-definitions-and-pools.yml`

### Key CI/CD Concepts

**Infrastructure Pipeline:**

- Triggers on changes to `infrastructure/**`
- Validates Terraform syntax (`terraform fmt`, `terraform validate`)
- Runs `terraform plan` on PRs
- Applies changes on merge to main

**Image Build Pipeline:**

- Triggers on changes to `images/packer/teams/**`
- Validates Packer templates
- Checks for required base provisioners (compliance)
- Builds images on merge to main
- Triggers definition updates after successful builds

**Business Logic:** Automated pipelines reduce manual intervention while maintaining security through validation gates. Terraform Enterprise provides additional governance with cost estimation, policy checks, and approval workflows.

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Network health check fails** | Verify NAT Gateway enabled, subnet size (/24+), DNS resolution |
| **Gallery not visible** | Check managed identity has Reader role on gallery |
| **Packer auth fails** | Run `az account show` and verify gallery permissions |
| **Build exit code 50** | PowerShell syntax error (avoid special chars in strings: ✓, ⚠) |
| **Build interrupted (sleep)** | Run `powercfg /change standby-timeout-ac 0` before build |
| **Image version not updating** | Run `03-create-definitions.ps1 -Update` to update definitions |
| **SKU validation error** | Run `00-validate-definitions.ps1 -Fix` to auto-correct storage types |
| **Intune not enrolling** | Verify Azure AD join with `dsregcmd /status` on Dev Box |

### Diagnostic Commands

```powershell
# Check network connection health
az devcenter admin network-connection show --name <name> --resource-group <rg> --query healthCheckStatus

# List gallery images
az sig image-definition list --gallery-name <gallery> --resource-group <rg>

# Verify role assignments
az role assignment list --assignee <user-id> --scope <resource-id>

# Enable Packer detailed logging
$env:PACKER_LOG = "1"
$env:PACKER_LOG_PATH = "packer.log"
.\build-image.ps1 -ImageType java
Get-Content packer.log | Select-String -Pattern "error|failed"
```

### Script Usage

```powershell
# Validate before deployment
.\00-validate-definitions.ps1

# Update definitions to new image versions
.\03-create-definitions.ps1 -Update

# Sync pools manually
.\04-sync-pools.ps1 -Verbose
```

## Additional Resources

**Microsoft Documentation:**

- [Microsoft DevCenter](https://learn.microsoft.com/azure/dev-box/)
- [Azure Compute Galleries](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries)
- [DevBox Network Requirements](https://learn.microsoft.com/azure/dev-box/how-to-configure-network-connections)
- [Custom Image Requirements](https://learn.microsoft.com/azure/dev-box/how-to-configure-dev-box-azure-image-builder)
- [Intune Integration](https://learn.microsoft.com/azure/dev-box/how-to-configure-intune-conditional-access-policies)

**Infrastructure as Code:**

- [Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Packer Azure Builder](https://www.packer.io/plugins/builders/azure)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Azure Landing Zones](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)

## Contributing

**Development Teams:** Create feature branch → Make changes to team Packer templates → Test locally → Update `devbox-definitions.json` → Create PR for team lead review

**Operations Team:** Infrastructure changes require additional review from network/security teams → Test in non-production first → Plan maintenance windows

## License

This sample is provided as-is under the MIT License.

## Support

- **Infrastructure issues:** Contact @operations-team
- **Image build issues:** Contact your team lead
- **General questions:** Check documentation or create GitHub issue

---

Happy DevBox Building! 🚀
