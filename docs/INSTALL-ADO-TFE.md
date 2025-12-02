# Installation Guide: Azure DevOps + Terraform Enterprise

This guide walks you through deploying DevBox infrastructure using **Azure DevOps pipelines with Terraform Enterprise**. This approach is designed for enterprise environments with multiple teams, governance requirements, and automated workflows.

## When to Use Azure DevOps + TFE

**Choose this method if:**

- ✅ Production environment
- ✅ Multiple teams collaborating (5+ people)
- ✅ Need audit trail and approval workflows
- ✅ Want automated deployments
- ✅ Enterprise governance required
- ✅ Separation of duties enforced
- ✅ Cost estimation and policy checks needed

**Consider CLI deployment if:**

- ❌ Proof-of-concept or testing
- ❌ Small team (1-5 people)
- ❌ Manual deployment is acceptable
- ❌ No CI/CD pipeline available

## Architecture Overview

This deployment model uses **two separate repositories** with distinct ownership:

```
microsoft.devcenter-infrastructure/    # Operations Team
├── infrastructure/                    # Terraform configs
├── images/packer/base/               # Security baseline image
└── .azuredevops/                     # Infrastructure pipelines

microsoft.devcenter-images/           # Development Teams
├── images/packer/teams/              # Team-specific images
├── images/definitions/               # DevBox definitions
└── .azuredevops/                     # Image build pipelines
```

**Business Logic:** Two repositories enforce separation of duties. Operations team controls infrastructure and security baseline. Development teams control their tools and images without waiting for IT approvals.

## Prerequisites

### Azure Resources

- Azure subscription with Owner or Contributor + User Access Administrator
- Azure DevOps organization
- Terraform Enterprise (TFE) or Terraform Cloud account

### Service Principals

Two service principals with different permissions:

1. **SP-DevBox-Infrastructure** (Operations)
   - Contributor on subscription/resource group
   - User Access Administrator (for role assignments)
   - Full access to DevCenter, networks, gallery

2. **SP-DevBox-Images** (Developers)
   - Reader on resource group
   - Contributor on Azure Compute Gallery only
   - Cannot modify infrastructure

### Software

- Azure CLI installed locally
- Git for repository management
- PowerShell 7+ (for setup scripts)

## Installation Steps

### Part 1: Azure Setup

#### Step 1: Create Service Principals

```powershell
# Infrastructure service principal (full access)
$infraSP = az ad sp create-for-rbac `
  --name "SP-DevBox-Infrastructure" `
  --role Contributor `
  --scopes /subscriptions/<subscription-id> `
  --sdk-auth

# Save output for later
$infraSP | Out-File -FilePath "infra-sp-credentials.json"

# Images service principal (limited access)
$imagesSP = az ad sp create-for-rbac `
  --name "SP-DevBox-Images" `
  --role Reader `
  --scopes /subscriptions/<subscription-id> `
  --sdk-auth

# Save output for later
$imagesSP | Out-File -FilePath "images-sp-credentials.json"
```

**Important:** Store these credentials securely. You'll need them for Azure DevOps variable groups.

#### Step 1a: (Optional) Store Secrets in Azure Key Vault

For production environments, store service principal secrets in Azure Key Vault instead of Azure DevOps variable groups:

```powershell
# Create Key Vault
az keyvault create \
  --name kv-devbox-secrets \
  --resource-group rg-devbox-prod \
  --location eastus \
  --enable-rbac-authorization

# Get current user object ID
$userObjectId = az ad signed-in-user show --query id -o tsv

# Grant yourself Key Vault Secrets Officer role
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee $userObjectId \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-devbox-prod/providers/Microsoft.KeyVault/vaults/kv-devbox-secrets

# Store secrets
az keyvault secret set --vault-name kv-devbox-secrets --name infra-sp-client-secret --value "<infra-sp-secret>"
az keyvault secret set --vault-name kv-devbox-secrets --name images-sp-client-secret --value "<images-sp-secret>"
az keyvault secret set --vault-name kv-devbox-secrets --name tfe-api-token --value "<tfe-token>"

# Grant service principals access to read their own secrets
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee <infra-sp-object-id> \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-devbox-prod/providers/Microsoft.KeyVault/vaults/kv-devbox-secrets

az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee <images-sp-object-id> \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-devbox-prod/providers/Microsoft.KeyVault/vaults/kv-devbox-secrets
```

**Note:** When using Key Vault, link it to Azure DevOps variable groups (see Step 3 in Part 2 below).

#### Step 2: Grant User Access Administrator Role

```powershell
# Infrastructure SP needs to assign roles
$infraSPObjectId = az ad sp list --display-name "SP-DevBox-Infrastructure" --query "[0].id" -o tsv

az role assignment create \
  --assignee $infraSPObjectId \
  --role "User Access Administrator" \
  --scope /subscriptions/<subscription-id>
```

### Part 2: Terraform Enterprise Setup

#### Step 1: Create TFE Workspace

1. Log in to [Terraform Enterprise](https://app.terraform.io/)
2. Navigate to your organization
3. Click "New Workspace"
4. Select "Version control workflow"
5. Configure:
   - **Name:** `devbox-infrastructure-prod`
   - **VCS Connection:** Connect to Azure DevOps
   - **Repository:** `microsoft.devcenter-infrastructure`
   - **Working Directory:** `infrastructure`
   - **Terraform Version:** Latest 1.x

#### Step 2: Configure TFE Variables

In your TFE workspace, add variables:

**Environment Variables:**

```
ARM_CLIENT_ID       = <infra-sp-client-id>
ARM_CLIENT_SECRET   = <infra-sp-client-secret>  [Sensitive]
ARM_SUBSCRIPTION_ID = <subscription-id>
ARM_TENANT_ID       = <tenant-id>
```

**Terraform Variables:**

```hcl
resource_group_name   = "rg-devbox-prod"
location             = "eastus"
environment          = "prod"
user_principal_id    = "<your-user-id>"
vnet_address_space   = ["10.4.0.0/16"]
subnet_address_prefix = ["10.4.0.0/24"]
enable_nat_gateway   = true
devcenter_name       = "dc-mycompany"
project_name         = "devbox-project"
gallery_name         = "galdevbox"
```

#### Step 3: Configure TFE Execution Mode

1. Go to workspace **Settings** → **General**
2. Set **Execution Mode:** Remote
3. Set **Apply Method:** Manual apply (requires approval)
4. Enable **Cost Estimation**
5. Enable **Run Triggers** if using multiple workspaces

#### Step 4: Create TFE API Token

1. Go to **User Settings** → **Tokens**
2. Click "Create an API token"
3. Name: `Azure DevOps Pipeline`
4. Save token securely for Azure DevOps

### Part 3: Azure DevOps Setup

#### Step 1: Create Two Repositories

```powershell
# Create infrastructure repository
az repos create \
  --name "microsoft.devcenter-infrastructure" \
  --organization https://dev.azure.com/<org> \
  --project <project>

# Create images repository
az repos create \
  --name "microsoft.devcenter-images" \
  --organization https://dev.azure.com/<org> \
  --project <project>
```

#### Step 2: Configure RBAC on Repositories

**Infrastructure Repository:**

- Settings → Security
- Add group: @operations-team (Contribute)
- Add group: @network-team (Read)
- Add group: @security-team (Read)
- Remove: Project Contributors (or set to Read only)

**Images Repository:**

- Settings → Security
- Add group: @dev-leads (Contribute)
- Add group: @developers (Contribute on /images/packer/teams/* only)
- Add group: @operations-team (Read)

#### Step 3: Create Variable Groups

**Option A: Direct Secrets (Simple)**

**Infrastructure Variables:**

1. Go to **Pipelines** → **Library** → **+ Variable group**
2. Name: `devbox-infrastructure-credentials`
3. Add variables:

```
AZURE_CLIENT_ID       = <infra-sp-client-id>
AZURE_CLIENT_SECRET   = <infra-sp-client-secret>  [Secret]
AZURE_SUBSCRIPTION_ID = <subscription-id>
AZURE_TENANT_ID       = <tenant-id>
TFE_TOKEN            = <tfe-api-token>             [Secret]
TFE_ORGANIZATION     = <tfe-org-name>
TFE_WORKSPACE        = devbox-infrastructure-prod
```

**Images Variables:**

1. Create another variable group: `devbox-images-credentials`
2. Add variables:

```
AZURE_CLIENT_ID       = <images-sp-client-id>
AZURE_CLIENT_SECRET   = <images-sp-client-secret>  [Secret]
AZURE_SUBSCRIPTION_ID = <subscription-id>
AZURE_TENANT_ID       = <tenant-id>
```

**Option B: Key Vault Integration (Production)**

If you created Azure Key Vault in Step 1a:

**Infrastructure Variables:**

1. Go to **Pipelines** → **Library** → **+ Variable group**
2. Name: `devbox-infrastructure-credentials`
3. Toggle **Link secrets from an Azure key vault as variables**
4. Select Azure subscription and Key Vault: `kv-devbox-secrets`
5. Authorize the connection
6. Add secrets:
   - `infra-sp-client-secret` → Map to variable `AZURE_CLIENT_SECRET`
   - `tfe-api-token` → Map to variable `TFE_TOKEN`
7. Add plain variables:
   - `AZURE_CLIENT_ID` = `<infra-sp-client-id>`
   - `AZURE_SUBSCRIPTION_ID` = `<subscription-id>`
   - `AZURE_TENANT_ID` = `<tenant-id>`
   - `TFE_ORGANIZATION` = `<tfe-org-name>`
   - `TFE_WORKSPACE` = `devbox-infrastructure-prod`

**Images Variables:**

1. Create another variable group: `devbox-images-credentials`
2. Link to Key Vault: `kv-devbox-secrets`
3. Add secrets:
   - `images-sp-client-secret` → Map to variable `AZURE_CLIENT_SECRET`
4. Add plain variables:
   - `AZURE_CLIENT_ID` = `<images-sp-client-id>`
   - `AZURE_SUBSCRIPTION_ID` = `<subscription-id>`
   - `AZURE_TENANT_ID` = `<tenant-id>`

**Key Vault Benefits:**
- ✅ Centralized secrets management
- ✅ Automatic secret rotation support
- ✅ Audit trail for secret access
- ✅ Secrets never stored in Azure DevOps
- ✅ Compliance and governance alignment

#### Step 4: Clone and Setup Infrastructure Repository

```powershell
# Clone infrastructure repo
git clone https://dev.azure.com/<org>/<project>/_git/microsoft.devcenter-infrastructure
cd microsoft.devcenter-infrastructure

# Copy infrastructure files
cp -r <source>/infrastructure ./
cp -r <source>/images/packer/base ./images/packer/
cp -r <source>/.azuredevops/infrastructure-repo/* ./.azuredevops/

# Create CODEOWNERS
echo "* @operations-team" > .github/CODEOWNERS
echo "/terraform/network*.tf @network-team @operations-team" >> .github/CODEOWNERS
echo "/policies/ @security-team @operations-team" >> .github/CODEOWNERS

# Commit and push
git add .
git commit -m "Initial infrastructure setup"
git push origin main
```

#### Step 5: Clone and Setup Images Repository

```powershell
# Clone images repo
git clone https://dev.azure.com/<org>/<project>/_git/microsoft.devcenter-images
cd microsoft.devcenter-images

# Copy image files
cp -r <source>/images/packer/teams ./images/packer/
cp -r <source>/images/definitions ./images/
cp -r <source>/.azuredevops/images-repo/* ./.azuredevops/

# Create infrastructure config (populated after infrastructure deployment)
mkdir .azuredevops/images-repo/config -Force
New-Item -Path ".azuredevops/images-repo/config/infrastructure-config.json" -ItemType File

# Create CODEOWNERS
echo "/packer/base/ @operations-team" > .github/CODEOWNERS
echo "/packer/teams/vscode* @vscode-team-leads" >> .github/CODEOWNERS
echo "/packer/teams/java* @java-team-leads" >> .github/CODEOWNERS
echo "/definitions/ @dev-leads @operations-team" >> .github/CODEOWNERS

# Commit and push
git add .
git commit -m "Initial images setup"
git push origin main
```

#### Step 6: Import Pipelines

**Infrastructure Repository Pipelines:**

1. Go to **Pipelines** → **New Pipeline**
2. Select "Azure Repos Git"
3. Select `microsoft.devcenter-infrastructure`
4. Select "Existing Azure Pipelines YAML file"
5. Path: `.azuredevops/terraform-infrastructure.yml`
6. Click "Run" to test
7. Repeat for `.azuredevops/build-baseline-image.yml`

**Images Repository Pipelines:**

1. Create new pipeline in images repository
2. Path: `.azuredevops/validate-devbox-images.yml`
3. Repeat for:
   - `.azuredevops/build-team-images.yml`
   - `.azuredevops/sync-definitions-and-pools.yml`

#### Step 7: Configure Branch Policies

**Infrastructure Repository:**

1. Go to **Repos** → **Branches** → `main` → **Branch policies**
2. Enable:
   - Require minimum number of reviewers: 2
   - Required reviewers: @operations-team
   - Check for linked work items
   - Build validation: `terraform-infrastructure` pipeline

**Images Repository:**

1. Configure branch policies on `main`
2. Enable:
   - Require minimum number of reviewers: 1
   - Required reviewers: @dev-leads
   - Build validation: `validate-devbox-images` pipeline

### Part 4: Initial Deployment

#### Step 1: Deploy Infrastructure via TFE

1. Trigger infrastructure pipeline (automatically runs on main branch changes)
2. Pipeline will:
   - Validate Terraform syntax
   - Trigger TFE workspace run
   - Wait for cost estimation
   - Pause for manual approval in TFE
3. Review and approve in TFE UI
4. TFE applies changes (~10-15 min)
5. Pipeline shows completion

**Manual TFE Trigger:**

1. Go to TFE workspace
2. Click "Actions" → "Start new run"
3. Add reason: "Initial infrastructure deployment"
4. Review plan → Confirm & Apply

#### Step 2: Populate Infrastructure Config

After infrastructure deployment:

```powershell
# Get Terraform outputs
cd infrastructure
terraform output -json > outputs.json

# Create config file for images repository
@{
    environments = @{
        prod = @{
            subscriptionId = "<subscription-id>"
            resourceGroup = "<rg-name>"
            galleryName = "<gallery-name>"
            devCenterName = "<devcenter-name>"
            baselineImageName = "SecurityBaselineImage"
            baselineImageVersion = "1.0.0"
            location = "eastus"
        }
    }
} | ConvertTo-Json -Depth 10 | Out-File "..\microsoft.devcenter-images\.azuredevops\images-repo\config\infrastructure-config.json"

# Commit to images repo
cd ..\microsoft.devcenter-images
git add .azuredevops/images-repo/config/infrastructure-config.json
git commit -m "Add infrastructure config from deployment"
git push origin main
```

#### Step 3: Build Baseline Image

1. In infrastructure repository, create branch: `build/baseline-v1.0.0`
2. Update `.azuredevops/build-baseline-image.yml` trigger if needed
3. Manually trigger pipeline: "Build Baseline Image"
4. Pipeline will:
   - Validate Packer template
   - Build SecurityBaselineImage (30-60 min)
   - Publish manifest
   - Notify development teams
5. Merge branch to main after successful build

**Manual build alternative:**

```powershell
cd images/packer/base
.\build-baseline-image.ps1 -ImageVersion "1.0.0" -Force
```

#### Step 4: Grant Gallery Access to Images Service Principal

After infrastructure and gallery are created:

```powershell
# Get gallery resource ID
$galleryId = az sig show --resource-group <rg> --gallery-name <gallery> --query id -o tsv

# Grant Images SP access to gallery
$imagesSPObjectId = az ad sp list --display-name "SP-DevBox-Images" --query "[0].id" -o tsv

az role assignment create \
  --assignee $imagesSPObjectId \
  --role "Contributor" \
  --scope $galleryId
```

#### Step 5: Build Team Images

Development teams can now build images:

1. Developer creates branch in images repository: `feature/java-image-update`
2. Updates `images/packer/teams/java-devbox.pkr.hcl` and `java-variables.pkrvars.hcl`
3. Creates pull request
4. PR triggers validation pipeline
5. Team lead reviews and approves
6. Merge to main triggers build pipeline
7. Pipeline builds only changed images (smart detection)
8. On success, triggers definition sync

**Pipeline flow:**

```
PR Created → Validate → Team Lead Review → Merge
                                              ↓
                               Build Changed Images (30-60 min)
                                              ↓
                            Update Definitions → Sync Pools
```

#### Step 6: Create DevBox Definitions

After images are built, operations team syncs definitions:

1. Review `images/definitions/devbox-definitions.json` in images repo
2. Trigger "Sync Definitions and Pools" pipeline, or
3. Automatic trigger after successful image build

Pipeline will:

1. Verify gallery sync (wait up to 30 min for Azure propagation)
2. Create/update definitions in DevCenter
3. Create/update pools from definitions
4. Report success/failures

### Part 5: Ongoing Operations

#### Update Team Images (Development Teams)

```powershell
# 1. Create feature branch
git checkout -b feature/update-java-image

# 2. Update Packer template
# Edit images/packer/teams/java-devbox.pkr.hcl

# 3. Update image version
# Edit images/packer/teams/java-variables.pkrvars.hcl
# image_version = "1.0.1"

# 4. Update definitions
# Edit images/definitions/devbox-definitions.json
# "imageVersion": "1.0.1"

# 5. Commit and push
git add .
git commit -m "Update Java image to v1.0.1: Add Maven 3.9"
git push origin feature/update-java-image

# 6. Create PR
az repos pr create \
  --title "Update Java DevBox image to v1.0.1" \
  --description "Adds Maven 3.9 and updates JDK to 21" \
  --source-branch feature/update-java-image \
  --target-branch main

# 7. After approval and merge, pipeline automatically builds
```

#### Update Infrastructure (Operations Team)

```powershell
# 1. Create feature branch
git checkout -b feature/add-network-rule

# 2. Update Terraform
# Edit infrastructure/main.tf or variables

# 3. Commit and push
git add .
git commit -m "Add network rule for Azure DevOps"
git push origin feature/add-network-rule

# 4. Create PR
az repos pr create \
  --title "Add network rule for Azure DevOps" \
  --source-branch feature/add-network-rule \
  --target-branch main

# 5. Pipeline runs terraform plan on PR
# 6. Operations + Network teams review
# 7. Merge triggers TFE workspace run
# 8. Review and approve in TFE UI
```

#### Update Baseline Image (Operations Team)

```powershell
# 1. Update baseline Packer template
# Edit images/packer/base/security-baseline.pkr.hcl

# 2. Increment version
# images/packer/base/security-baseline.pkrvars.hcl
# image_version = "1.0.1"

# 3. Trigger baseline build pipeline manually
# 4. After success, notify development teams to rebuild
# 5. Dev teams update baseline_image_version in their variables
```

## Verification

### Verify Pipeline Configuration

```powershell
# List all pipelines
az pipelines list --organization https://dev.azure.com/<org> --project <project>

# Check pipeline runs
az pipelines runs list --organization https://dev.azure.com/<org> --project <project>

# View specific run
az pipelines runs show --id <run-id> --organization https://dev.azure.com/<org> --project <project>
```

### Verify TFE Workspace

1. Log in to Terraform Enterprise
2. Navigate to workspace: `devbox-infrastructure-prod`
3. Verify:
   - Latest run status: Applied
   - Cost estimate available
   - State file present
   - Outputs populated

### Verify Azure Resources

```powershell
# Check DevCenter
az devcenter admin dev-center show --name <devcenter> --resource-group <rg>

# Check definitions
az devcenter admin devbox-definition list --dev-center-name <devcenter> --resource-group <rg>

# Check pools
az devcenter admin pool list --project <project> --resource-group <rg>

# Check gallery images
az sig image-definition list --gallery-name <gallery> --resource-group <rg>
```

## Troubleshooting

### Pipeline Failures

**Terraform validation fails:**

```powershell
# Run locally to debug
cd infrastructure
terraform init
terraform validate
terraform fmt -check
```

**TFE workspace run fails:**

- Review run logs in TFE UI
- Check service principal permissions
- Verify variable values in TFE workspace

**Image build pipeline fails:**

- Check service principal has gallery access
- Review Packer logs in pipeline output
- Verify baseline image exists
- Check for quota limits on VM SKUs

### Service Principal Issues

```powershell
# Test infrastructure SP
az login --service-principal \
  --username <client-id> \
  --password <client-secret> \
  --tenant <tenant-id>

az account show

# Test permissions
az group show --name <rg>

# Test images SP
az login --service-principal \
  --username <client-id> \
  --password <client-secret> \
  --tenant <tenant-id>

# Should have gallery access
az sig show --resource-group <rg> --gallery-name <gallery>
```

### Cross-Repository Integration Issues

**infrastructure-config.json not found:**

- Verify file committed to images repository
- Check file path: `.azuredevops/images-repo/config/infrastructure-config.json`
- Validate JSON syntax

**Baseline image not found by dev teams:**

- Verify baseline image build completed
- Check image version matches in config file
- Confirm gallery sync completed (5-30 min delay)

## Monitoring and Maintenance

### Set Up Alerts

```powershell
# Create alert for pipeline failures
az monitor metrics alert create \
  --name "DevBox Pipeline Failures" \
  --resource-group <rg> \
  --scopes <pipeline-resource-id> \
  --condition "count failed runs > 0" \
  --action <action-group-id>
```

### Review TFE Audit Logs

1. Go to TFE Organization → Settings → Audit Trails
2. Filter by workspace: `devbox-infrastructure-prod`
3. Review who approved/rejected runs
4. Export for compliance reporting

### Cost Monitoring

```powershell
# Enable cost management in TFE
# Automatic cost estimation on every plan

# View Azure costs
az consumption usage list \
  --start-date $(Get-Date -Format "yyyy-MM-01") \
  --end-date $(Get-Date -Format "yyyy-MM-dd")
```

## Migration from CLI to Azure DevOps + TFE

If you deployed with CLI and want to migrate:

1. **Import existing state to TFE:**

```powershell
cd infrastructure

# Configure TFE backend
cat >> backend.tf <<EOF
terraform {
  backend "remote" {
    organization = "<tfe-org>"
    workspaces {
      name = "devbox-infrastructure-prod"
    }
  }
}
EOF

# Initialize with migration
terraform init -migrate-state
```

2. **Set up repositories and pipelines** (follow steps above)
3. **Verify state migration successful** in TFE UI
4. **Remove local state files** (now in TFE)

## Next Steps

- **Set up notifications**: Configure email/Teams notifications for pipeline runs
- **Configure retention policies**: Set how long to keep pipeline runs and logs
- **Plan disaster recovery**: Enable gallery replication to secondary region
- **Implement policy as code**: Use Azure Policy or Sentinel (TFE) for governance
- **Set up monitoring dashboards**: Azure Monitor or Grafana for DevBox metrics

## Additional Resources

- [Main README](../README.md)
- [CLI Installation Guide](INSTALL-CLI.md)
- [Azure DevOps Pipeline Documentation](https://learn.microsoft.com/azure/devops/pipelines/)
- [Terraform Enterprise Documentation](https://www.terraform.io/cloud-docs)
- [Two-Repository Architecture Details](../.azuredevops/TWO-REPO-ARCHITECTURE.md)
