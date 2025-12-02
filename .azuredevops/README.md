# Azure DevOps Pipelines for DevBox with Terraform Enterprise

This directory contains Azure DevOps pipeline definitions for a **two-repository model** that separates infrastructure management (Operations Team) from image customization (Development Teams).

## 🎯 Quick Start

This deployment uses **two separate repositories** with clear separation of duties:

- **📁 `infrastructure-repo/`** - Operations Team (DevCenter, networks, baseline image)
- **📁 `images-repo/`** - Development Teams (team images, definitions, pools)

👉 **[Read the complete architecture guide](TWO-REPO-ARCHITECTURE.md)** for detailed information.

## 📂 Repository Structure

### Infrastructure Repository Pipelines (Operations Team)
```
infrastructure-repo/
├── terraform-infrastructure.yml    # TFE integration, infrastructure validation
└── build-baseline-image.yml        # Builds SecurityBaselineImage (monthly)
```

**Who uses:** Operations Team, Security Team  
**Access:** Restricted to operations team only

### Images Repository Pipelines (Development Teams)
```
images-repo/
├── validate-devbox-images.yml         # PR validation (security checks)
├── build-team-images.yml              # Builds team images (auto-trigger)
├── sync-definitions-and-pools.yml     # Updates DevCenter (auto/manual)
└── config/
    └── infrastructure-config.json      # References to infrastructure
```

**Who uses:** All development teams  
**Access:** Developers can update their team's images

## 🚀 Pipeline Overview

| Pipeline | Repository | Purpose | Trigger | Frequency |
|----------|-----------|---------|---------|-----------|
| `terraform-infrastructure.yml` | Infrastructure | TFE integration | PR + Main | Quarterly |
| `build-baseline-image.yml` | Infrastructure | Security baseline | Manual | Monthly |
| `validate-devbox-images.yml` | Images | Security validation | PR | Continuous |
| `build-team-images.yml` | Images | Build team images | Main | Weekly |
| `sync-definitions-and-pools.yml` | Images | Update DevCenter | Auto/Manual | After builds |

## 🔑 Key Benefits

### Separation of Duties
- ✅ **Infrastructure Team:** Controls DevCenter, networks, and security baseline
- ✅ **Development Teams:** Independent image updates without infrastructure access
- ✅ **Clear Boundaries:** No accidental infrastructure changes by developers

### Agility
- ✅ **Independent Deployments:** Teams update images without coordinating with ops
- ✅ **Fast Iterations:** Image changes don't require infrastructure approval
- ✅ **Smart Builds:** Only changed images are rebuilt (saves time and cost)

### Security & Compliance
- ✅ **Enforced Baseline:** All images must use SecurityBaselineImage
- ✅ **Security Scanning:** Automatic validation blocks dangerous patterns
- ✅ **Audit Trail:** Separate repos provide clear ownership and history

## 📋 Typical Workflows

### Developer Updates Image (Weekly/Continuous)
```
1. Developer: Update packer/teams/java-devbox.pkr.hcl
2. Create PR → validate-devbox-images.yml validates security
3. Merge to main → build-team-images.yml auto-triggers
4. Only Java image rebuilds (60 min)
5. sync-definitions-and-pools.yml updates DevCenter
6. Users can provision new version ✅
│          2. Build team-specific images (parallel)      │
│          3. Update DevBox definitions                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

### Azure DevOps Setup

#### 1. Service Connections

Create Azure service connections with appropriate service principals:

**For Infrastructure (used by TFE):**
```bash
# Create service principal
az ad sp create-for-rbac --name "SP-DevBox-Infrastructure" \
  --role Contributor \
  --scopes /subscriptions/{subscription-id}

# Grant additional role for RBAC operations
az role assignment create \
  --assignee {app-id} \
  --role "User Access Administrator" \
  --scope /subscriptions/{subscription-id}
```

**For Image Builds (used by ADO pipelines):**
```bash
# Create service principal for Packer
az ad sp create-for-rbac --name "SP-DevBox-Images" \
  --role Contributor \
  --scopes /subscriptions/{subscription-id}/resourceGroups/{gallery-rg}
```

#### 2. Variable Groups

**`devbox-azure-credentials`** (for build-devbox-images.yml):
```yaml
ARM_SUBSCRIPTION_ID: "<subscription-id>"
ARM_CLIENT_ID: "<sp-client-id>"
ARM_CLIENT_SECRET: "<sp-client-secret>"  # Mark as secret
ARM_TENANT_ID: "<tenant-id>"
```

**`terraform-enterprise-config`** (for terraform-infrastructure.yml):
```yaml
TFE_ORG: "<your-tfe-organization>"
TFE_WORKSPACE: "devbox-infrastructure-prod"
TFE_TOKEN: "<tfe-api-token>"  # Mark as secret
```

#### 3. Service Connections

Create service connection in ADO:
- Name: `DevBox-ServiceConnection`
- Type: Azure Resource Manager
- Authentication: Service Principal
- Use the SP created above

### Terraform Enterprise Setup

#### 1. Create Workspace

```hcl
# Workspace Configuration
Name: devbox-infrastructure-prod
Organization: your-org-name
Execution Mode: Remote
Terraform Version: Latest (or specific version)

# VCS Connection
Repository: azure-devops.com/your-org/microsoft.devcenter
Branch: main
Working Directory: infrastructure

# Trigger Patterns (VCS Settings)
Automatic Run Triggering: Enabled
VCS Branch: main
Automatic speculative plans: Enabled (for PRs)
```

#### 2. Configure Workspace Variables

**Environment Variables (mark as sensitive):**
```bash
ARM_CLIENT_ID       = "<service-principal-client-id>"
ARM_CLIENT_SECRET   = "<service-principal-secret>"
ARM_SUBSCRIPTION_ID = "<azure-subscription-id>"
ARM_TENANT_ID       = "<azure-tenant-id>"
```

**Terraform Variables:**
```hcl
resource_group_name     = "rg-devbox-multi-roles"
location               = "eastus"
user_principal_id      = "<user-or-group-object-id>"
user_principal_type    = "User"  # or "Group" or "ServicePrincipal"
enable_nat_gateway     = true
```

## Pipeline Configuration

### validate-devbox-images.yml

**Purpose:** Ensures Packer templates follow security best practices

**Checks:**
- ✓ All team images reference `SecurityBaselineImage` (not direct Microsoft images)
- ✓ No dangerous patterns (disabled Defender, UAC, Firewall)
- ✓ Valid Packer HCL syntax

**When it runs:**
- On pull requests affecting `images/packer/teams/**`
- On pushes to main affecting `images/packer/teams/**`

**Status:** ✅ Production Ready

### terraform-infrastructure.yml

**Purpose:** Validates Terraform code and tracks TFE workspace runs

**Checks:**
- ✓ Terraform formatting (`terraform fmt -check`)
- ✓ Terraform validation (`terraform validate`)
- ✓ Provides link to TFE workspace run

**When it runs:**
- On pull requests affecting `infrastructure/**`
- On pushes to main affecting `infrastructure/**`

**TFE Integration:** Workspace auto-triggers via VCS connection

### build-devbox-images.yml

**Purpose:** Builds custom DevBox images and updates definitions + pools (full automation)

**Stages:**
1. **BuildBaseline:** Creates security baseline image (~30 min)
2. **BuildTeamImages:** Builds team-specific images in parallel (~60 min each)
3. **VerifyGallerySync:** Waits for images to sync to DevCenter (~5-30 min)
4. **UpdateDefinitions:** Updates DevBox definitions with new images (~2 min)
5. **SyncPools:** Synchronizes pools with updated definitions (~2 min)
6. **PublishArtifacts:** Publishes build logs

**When it runs:**
- On pushes to main affecting `images/**`

**Variables:**
- `imageVersion`: Set to `$(Build.BuildNumber)`
- Service principal credentials from variable group

**Note:** This is the primary pipeline for image changes. It handles everything end-to-end.

### sync-pools-only.yml

**Purpose:** Synchronize pools without rebuilding images (fast path for pool config changes)

**Stages:**
1. **ValidateDefinitions:** Validates configuration files (~1 min)
2. **SyncPools:** Synchronizes pools with existing definitions (~2 min)
3. **Summary:** Displays operation summary

**When it runs:**
- Manual trigger only (does not auto-trigger on file changes)

**Use cases:**
- Pool configuration changes (schedules, administrator settings)
- Adding new pools for existing definitions
- Fixing pool synchronization issues after manual changes

**Variables:**
- Service principal credentials from variable group

**Note:** This pipeline does NOT rebuild images. Use for pool-only updates.

## Usage

### Setting Up Pipelines in Azure DevOps

1. Navigate to **Pipelines** → **Create Pipeline**
2. Select **Azure Repos Git** (or your repo type)
3. Select your repository
4. Choose **Existing Azure Pipelines YAML file**
5. Select pipeline file:
   - `.azuredevops/validate-devbox-images.yml`
   - `.azuredevops/terraform-infrastructure.yml`
   - `.azuredevops/build-devbox-images.yml`
   - `.azuredevops/sync-pools-only.yml` (optional - for manual pool updates)
6. Save and run

**Note:** Set `sync-pools-only.yml` trigger to "Manual" to prevent accidental runs.

### Typical Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/add-python-image

# 2. Add new Packer template
# images/packer/teams/python-devbox.pkr.hcl

# 3. Create pull request
# → validate-devbox-images.yml runs automatically
# → Checks security baseline usage and patterns

# 4. Address any validation failures
# → Fix issues found by validation

# 5. Get PR approval and merge
# → build-devbox-images.yml runs automatically
# → Builds new image and updates definitions
```

### Infrastructure Changes Workflow

```bash
# 1. Create feature branch
git checkout -b feature/add-vnet-peering

# 2. Modify Terraform
# infrastructure/main.tf

# 3. Create pull request
# → terraform-infrastructure.yml validates formatting and syntax
# → TFE creates speculative plan (if configured)

# 4. Review TFE plan
# → Check cost estimation
# → Review policy checks
# → Get approval

# 5. Merge to main
# → TFE workspace auto-triggers
# → Apply infrastructure changes
```

### Pool Configuration Changes Workflow

```bash
# Option A: Fast path (pool config only, no images)
# 1. Update pool configurations
# Edit: images/definitions/devbox-definitions.json (pools section)

# 2. Commit and push
git add images/definitions/devbox-definitions.json
git commit -m "Update pool schedules"
git push

# 3. Manually trigger sync-pools-only.yml pipeline
# → Takes 2-5 minutes
# → No image rebuilds

# Option B: Automatic (with image changes)
# 1. Modify images AND definitions
# → build-devbox-images.yml auto-triggers
# → Rebuilds images AND syncs pools
# → Takes 2-3 hours but fully automated
```

**When to use which:**
- **sync-pools-only.yml:** Quick pool config updates (schedules, admin settings)
- **build-devbox-images.yml:** Image changes (automatically handles pools too)

## Monitoring and Troubleshooting

### Pipeline Failures

**Validation Pipeline Fails:**
```bash
# Common issues:
# 1. Packer template doesn't reference SecurityBaselineImage
#    → Update source block to use baseline image

# 2. Dangerous pattern detected
#    → Remove commands that disable security features

# 3. Packer syntax error
#    → Run: packer validate your-template.pkr.hcl
```

**Build Pipeline Fails:**
```bash
# Common issues:
# 1. Service principal permissions
#    → Verify SP has Contributor on gallery resource group

# 2. Image build timeout
#    → Increase job timeoutInMinutes
#    → Check VM provisioning in Azure

# 3. Definition update fails
#    → Verify devcenter-settings.json exists
#    → Check Dev Center permissions
```

**TFE Workspace Issues:**
```bash
# 1. Workspace not triggering
#    → Verify VCS connection is active
#    → Check working directory path
#    → Ensure branch matches configuration

# 2. Authentication errors
#    → Verify ARM_* environment variables in workspace
#    → Check service principal hasn't expired
```

### Viewing TFE Runs

From terraform-infrastructure.yml output:
```
Monitor the run at:
https://app.terraform.io/app/{org}/workspaces/{workspace}
```

### Build Artifacts

Access Packer build logs:
1. Navigate to pipeline run
2. Go to **Artifacts** tab
3. Download `packer-build-logs`

## Security Best Practices

1. **Always use SecurityBaselineImage** for team images
2. **Never disable security features** (Defender, UAC, Firewall)
3. **Mark secrets as sensitive** in variable groups
4. **Use separate service principals** for different operations
5. **Enable branch policies** requiring PR validation
6. **Review TFE plans** before applying
7. **Enable Sentinel policies** in TFE for governance

## Cost Optimization

- **Parallel image builds** reduce total pipeline time
- **Path filters** prevent unnecessary pipeline runs
- **TFE cost estimation** helps predict Azure costs
- **Scheduled builds** can run during off-peak hours

## 📖 Documentation

- **[TWO-REPO-ARCHITECTURE.md](TWO-REPO-ARCHITECTURE.md)** - Complete architecture guide, workflows, and migration steps
- **Pipeline YAML files** - Inline documentation in each pipeline file
- **config/infrastructure-config.json** - Infrastructure reference schema

## 🚀 Getting Started

### Step 1: Review the Architecture
Read [TWO-REPO-ARCHITECTURE.md](TWO-REPO-ARCHITECTURE.md) to understand:
- Why two repositories?
- How teams interact
- Deployment cadences
- Security model

### Step 2: Create Repositories
```bash
# Create infrastructure repository (Operations Team)
az repos create --name "microsoft.devcenter-infrastructure"

# Create images repository (Development Teams)
az repos create --name "microsoft.devcenter-images"
```

### Step 3: Set Up Pipelines
- **Infrastructure repo:** Copy files from `infrastructure-repo/`
- **Images repo:** Copy files from `images-repo/`
- Configure service connections and variable groups
- Import YAML pipelines in Azure DevOps

### Step 4: Configure Access Control
- **Infrastructure repo:** Restrict to operations team
- **Images repo:** All developers (read), team leads (write to their folders)

### Step 5: Deploy
1. Operations team deploys infrastructure via TFE
2. Operations team builds baseline image
3. Development teams build their team images
4. Users can provision Dev Boxes!

## ❓ Common Questions

**Q: Can developers see infrastructure code?**  
A: No, infrastructure is in a separate repository with restricted access.

**Q: How do developers reference the baseline image?**  
A: Via `config/infrastructure-config.json` provided by operations team.

**Q: What happens when the baseline updates?**  
A: Dev teams are notified and rebuild images on their schedule.

**Q: Can we use this with GitHub Actions instead?**  
A: Yes! The separation model works with any CI/CD system. You'll need to adapt the YAML syntax.

## 🤝 Contributing

This is a reference implementation. Feel free to:
- Adapt to your organization's needs
- Modify pipeline triggers and stages
- Add additional validation steps
- Integrate with your notification systems

## 📚 Additional Resources

- [Terraform Enterprise](https://www.terraform.io/docs/enterprise)
- [Azure DevOps Pipelines](https://docs.microsoft.com/azure/devops/pipelines/)
- [HashiCorp Packer](https://www.packer.io/docs/builders/azure)
- [Azure Dev Box](https://docs.microsoft.com/azure/dev-box/)
