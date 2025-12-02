# Two-Repository Architecture for DevBox

## 🏗️ Repository Separation

### Repository 1: Infrastructure (Operations Team)
```
microsoft.devcenter-infrastructure/
├── terraform/
│   ├── main.tf                    # DevCenter, Gallery, Networks
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
├── images/
│   └── packer/
│       └── base/
│           ├── security-baseline.pkr.hcl   # Base security image
│           └── build-baseline-image.ps1
├── .azuredevops/
│   ├── deploy-infrastructure.yml           # TFE integration
│   └── build-baseline-image.yml            # Base image only
└── README.md

Access:
  ✅ Operations Team (full access)
  ✅ Security Team (read, PR approval required)
  ❌ Developers (no access)
```

### Repository 2: Images (Development Teams)
```
microsoft.devcenter-images/
├── packer/
│   └── teams/
│       ├── vscode-devbox.pkr.hcl
│       ├── java-devbox.pkr.hcl
│       ├── dotnet-devbox.pkr.hcl
│       └── datascience-devbox.pkr.hcl
├── definitions/
│   └── devbox-definitions.json        # Definitions + Pools config
├── .azuredevops/
│   ├── validate-team-images.yml       # PR validation
│   ├── build-team-images.yml          # Build team images
│   └── sync-definitions-and-pools.yml # Update DevCenter
└── README.md

Access:
  ✅ All Developers (read)
  ✅ Team Leads (write to team folders)
  ✅ DevOps (write to definitions)
  ❌ Operations Team (read-only for support)
```

---

## 🔐 Separation of Duties

| Responsibility | Infrastructure Repo | Images Repo |
|----------------|-------------------|-------------|
| **Deploy DevCenter** | ✅ Operations | ❌ No access |
| **Configure Networks** | ✅ Operations | ❌ No access |
| **Manage Gallery** | ✅ Operations | ❌ No access |
| **Security Baseline Image** | ✅ Operations | ❌ No access |
| **Team Images** | ❌ No access | ✅ Developers |
| **DevBox Definitions** | ❌ No access | ✅ Developers |
| **Pool Configuration** | ❌ No access | ✅ Developers |

---

## 🔄 Cross-Repository Integration

### How Developers Reference the Baseline Image

**Infrastructure Team publishes baseline image details:**
```json
// Published to shared location (Azure Storage, Artifacts, etc.)
// File: baseline-image-manifest.json
{
  "galleryName": "acg-devbox-prod-eastus",
  "galleryResourceGroup": "rg-devbox-infrastructure",
  "baselineImageName": "SecurityBaselineImage",
  "latestVersion": "2024.12.001",
  "publishedDate": "2024-12-02T10:30:00Z",
  "source": {
    "repository": "microsoft.devcenter-infrastructure",
    "build": "20241202.1"
  }
}
```

**Development Teams reference in Packer:**
```hcl
# packer/teams/java-devbox.pkr.hcl
source "azure-arm" "java_devbox" {
  # References baseline from infrastructure team
  custom_managed_image_name                = "SecurityBaselineImage"
  custom_managed_image_resource_group_name = var.gallery_resource_group
  
  # Or use shared image gallery reference
  shared_image_gallery {
    subscription         = var.subscription_id
    resource_group       = var.gallery_resource_group
    gallery_name         = var.gallery_name
    image_name           = "SecurityBaselineImage"
    image_version_latest = true
  }
}
```

---

## 🚀 Pipeline Architecture

### Infrastructure Repository Pipelines

#### 1. `deploy-infrastructure.yml`
```yaml
# Runs: Rarely (infrastructure changes)
# Deploys: DevCenter, Gallery, Networks via TFE
# Trigger: Push to main (infrastructure/**)

Stages:
  - Validate (PR only)
      └─ terraform validate
  - Notify TFE (main only)
      └─ TFE workspace auto-deploys
```

#### 2. `build-baseline-image.yml`
```yaml
# Runs: Monthly or when security updates needed
# Builds: SecurityBaselineImage (hardened Windows)
# Trigger: Manual or scheduled

Stages:
  - Build Baseline
      └─ Packer builds SecurityBaselineImage
      └─ Publishes to Compute Gallery
  - Publish Manifest
      └─ Updates baseline-image-manifest.json
      └─ Publishes to Azure Storage/Artifacts
  - Notify Teams
      └─ Sends notification to dev teams
      └─ "New baseline available: v2024.12.001"
```

**Frequency:** Monthly or quarterly

---

### Images Repository Pipelines

#### 1. `validate-team-images.yml`
```yaml
# Runs: On every PR
# Validates: Packer templates, security patterns
# Trigger: PR to main

Stages:
  - Validate Baseline Usage
      └─ Ensures all images reference SecurityBaselineImage
      └─ BLOCKS direct Microsoft base images
  - Security Scan
      └─ Scan for dangerous patterns
  - Packer Validate
      └─ Syntax validation
```

#### 2. `build-team-images.yml`
```yaml
# Runs: When team images change
# Builds: Team-specific images
# Trigger: Push to main (packer/teams/**)

Stages:
  - Download Baseline Manifest
      └─ Get latest baseline version from infrastructure team
      └─ Verify baseline image exists in gallery
  
  - Build Team Images (Parallel)
      └─ VSCode Image (if changed)
      └─ Java Image (if changed)
      └─ .NET Image (if changed)
      └─ DataScience Image (if changed)
  
  - Publish Image Manifest
      └─ Create image-versions.json
      └─ Lists all built images with versions
```

**Frequency:** Weekly or continuous

#### 3. `sync-definitions-and-pools.yml`
```yaml
# Runs: After images are built OR manually
# Updates: DevBox definitions and pools in DevCenter
# Trigger: Manual or after build-team-images.yml succeeds

Stages:
  - Verify Gallery Sync
      └─ Wait for images to sync to DevCenter (5-30 min)
  
  - Update Definitions
      └─ Create/update DevBox definitions
      └─ Points to latest image versions
  
  - Sync Pools
      └─ Create/update DevBox pools
      └─ References updated definitions
```

**Frequency:** After each image build

---

## 🔑 Authentication & Permissions

### Service Principals

#### Infrastructure Service Principal
```yaml
Name: SP-DevBox-Infrastructure
Permissions:
  - Contributor on Infrastructure resource group
  - User Access Administrator (for RBAC)
  - Network Contributor
Used by:
  - Infrastructure repository (TFE)
  - build-baseline-image.yml
```

#### Images Service Principal
```yaml
Name: SP-DevBox-Images
Permissions:
  - Contributor on Compute Gallery (images only)
  - Reader on Infrastructure resource group
  - DevCenter Dev Box Administrator on Project
Used by:
  - Images repository (all pipelines)
  - build-team-images.yml
  - sync-definitions-and-pools.yml
```

**Key Principle:** Images SP cannot modify infrastructure, only add images and definitions.

---

## 📊 Typical Workflows

### Workflow 1: Infrastructure Team Updates Baseline (Monthly)

```
1. Operations Team: Security updates needed
   └─ Update: images/packer/base/security-baseline.pkr.hcl
   └─ Commit to infrastructure repo

2. Pipeline: build-baseline-image.yml (manual trigger)
   └─ Build SecurityBaselineImage v2024.12.001
   └─ Publish to gallery (45 min)
   └─ Update baseline-image-manifest.json
   └─ Notify dev teams via Slack/Email

3. Development Teams: Rebuild images on their schedule
   └─ Update devbox-definitions.json with new versions
   └─ Trigger build-team-images.yml
   └─ Team images rebuild using new baseline
```

**Frequency:** Monthly  
**Impact:** Dev teams choose when to adopt new baseline

### Workflow 2: Developer Updates Team Image (Continuous)

```
1. Developer: Add Python 3.12 to DataScience image
   └─ Update: packer/teams/datascience-devbox.pkr.hcl
   └─ Update version: images/definitions/devbox-definitions.json
   └─ Create PR to images repo

2. PR: validate-team-images.yml runs
   └─ ✓ References SecurityBaselineImage
   └─ ✓ No dangerous patterns
   └─ ✓ Packer syntax valid
   └─ PR approved and merged

3. Main branch: build-team-images.yml auto-triggers
   └─ Builds ONLY DataScience image (60 min)
   └─ Other images skipped (no changes)

4. Auto-trigger: sync-definitions-and-pools.yml
   └─ Wait for gallery sync (10 min)
   └─ Update DataScience-DevBox definition
   └─ Sync pools (2 min)
   └─ Users can now provision new version
```

**Frequency:** Weekly/continuous  
**Impact:** Only changed images rebuild

### Workflow 3: Operations Team Deploys New Environment

```
1. Operations Team: Deploy to new region (eastus2)
   └─ Update: terraform/main.tf (add new region)
   └─ Commit to infrastructure repo

2. PR: deploy-infrastructure.yml validates
   └─ terraform validate
   └─ TFE shows speculative plan

3. Merge: TFE workspace deploys
   └─ Create DevCenter in eastus2
   └─ Create Compute Gallery
   └─ Configure networks (30 min)

4. Operations: Build baseline for new region
   └─ Manually trigger build-baseline-image.yml
   └─ Select region: eastus2
   └─ Baseline image created (45 min)

5. Development Teams: Deploy images to new region
   └─ Update definitions with new gallery/region
   └─ Trigger build-team-images.yml
   └─ All team images build to new region (2 hours)
```

**Frequency:** Rarely (new environments)  
**Impact:** Full deployment to new region

---

## 🔄 Cross-Repository Dependencies

### How Image Repo Knows About Infrastructure

#### Option A: Configuration File (Recommended)
```json
// images/config/infrastructure-config.json
{
  "environments": {
    "prod": {
      "galleryName": "acg-devbox-prod-eastus",
      "galleryResourceGroup": "rg-devbox-infrastructure-prod",
      "devCenterName": "dc-devbox-prod",
      "devCenterResourceGroup": "rg-devbox-infrastructure-prod",
      "baselineImageName": "SecurityBaselineImage",
      "region": "eastus"
    },
    "dev": {
      "galleryName": "acg-devbox-dev-eastus",
      "galleryResourceGroup": "rg-devbox-infrastructure-dev",
      "devCenterName": "dc-devbox-dev",
      "devCenterResourceGroup": "rg-devbox-infrastructure-dev",
      "baselineImageName": "SecurityBaselineImage",
      "region": "eastus"
    }
  }
}
```

**Managed by:** Operations team  
**Updated:** When infrastructure changes  
**Stored:** In images repository

#### Option B: Azure Key Vault
```
Infrastructure team stores in Key Vault:
  - gallery-name
  - gallery-resource-group
  - devcenter-name
  - baseline-image-version

Images pipelines read from Key Vault
```

#### Option C: Pipeline Variables
```yaml
# Images repo variable group: devbox-infrastructure-config
GALLERY_NAME: "acg-devbox-prod-eastus"
GALLERY_RG: "rg-devbox-infrastructure-prod"
DEVCENTER_NAME: "dc-devbox-prod"
DEVCENTER_RG: "rg-devbox-infrastructure-prod"
```

**Recommendation:** Use Option A (config file) for simplicity and Git tracking.

---

## 📁 File Structure Comparison

### Before (Single Repo)
```
microsoft.devcenter/
├── infrastructure/          # Ops team
└── images/                  # Dev team
    ├── packer/
    │   ├── base/           # Ops team (❌ shared repo)
    │   └── teams/          # Dev team
    └── definitions/         # Dev team

Problem: Mixed ownership, shared repo
```

### After (Two Repos)
```
microsoft.devcenter-infrastructure/  # Ops repo
├── terraform/
└── images/packer/base/

microsoft.devcenter-images/          # Dev repo
├── packer/teams/
├── definitions/
└── config/
    └── infrastructure-config.json   # Ops provides this

Solution: Clear ownership, separate repos
```

---

## 🎯 Benefits of Two-Repository Model

### Security
- ✅ Infrastructure secrets isolated
- ✅ Base image controlled by ops team
- ✅ Developers can't modify infrastructure
- ✅ Separate RBAC policies

### Agility
- ✅ Dev teams update images independently
- ✅ No infrastructure changes needed for image updates
- ✅ Faster PR reviews (smaller scope)
- ✅ Parallel development

### Compliance
- ✅ Audit trail per team
- ✅ Approval workflows per repo
- ✅ Clear ownership boundaries
- ✅ Reduced blast radius

### Operations
- ✅ Infrastructure deploys rarely (stable)
- ✅ Base image updates monthly (controlled)
- ✅ Team images update continuously (agile)
- ✅ Independent deployment cadences

---

## 🚦 Deployment Cadence

| Component | Repo | Frequency | Trigger | Owner |
|-----------|------|-----------|---------|-------|
| **Infrastructure** | infra | Quarterly | Manual/TFE | Ops Team |
| **Base Image** | infra | Monthly | Manual | Ops Team |
| **Team Images** | images | Weekly | Auto | Dev Teams |
| **Definitions** | images | Weekly | Auto | Dev Teams |
| **Pools** | images | As needed | Auto | Dev Teams |

---

## 🔔 Communication Between Teams

### When Baseline Updates
```
Infrastructure Pipeline (build-baseline-image.yml):
  └─ Success
      └─ Publish to Azure Storage: baseline-image-manifest.json
      └─ Send notification:
          • Slack: #devbox-announcements
          • Email: dev-teams@company.com
          • Message: "New baseline v2024.12.001 available"

Developer Action:
  └─ Update devbox-definitions.json at their convenience
  └─ Rebuild team images when ready
```

### When Infrastructure Changes
```
Infrastructure Team:
  └─ Update infrastructure-config.json in images repo
  └─ Create PR to images repo
  └─ Message: "Updated gallery name for prod environment"

Developer Action:
  └─ Review PR (no code changes needed)
  └─ Merge PR
  └─ Next pipeline run uses new config automatically
```

---

## 🎓 Onboarding New Developers

### Images Repository Only
```
1. Clone images repository
2. No access to infrastructure (don't need it)
3. Edit team-specific Packer templates
4. Create PR → validation runs
5. Merge → images build automatically
6. No infrastructure knowledge required ✅
```

### Infrastructure Access Not Needed
- ❌ Don't need Terraform knowledge
- ❌ Don't need network configuration
- ❌ Don't need Azure subscription permissions
- ✅ Only need Packer and image definitions

---

## 📋 Migration Path

### Phase 1: Prepare Repositories
1. Create `microsoft.devcenter-infrastructure` repo
2. Create `microsoft.devcenter-images` repo
3. Set up RBAC policies

### Phase 2: Move Infrastructure
1. Copy `terraform/` to infrastructure repo
2. Copy `images/packer/base/` to infrastructure repo
3. Create infrastructure pipelines

### Phase 3: Move Images
1. Copy `images/packer/teams/` to images repo
2. Copy `images/definitions/` to images repo
3. Create config/infrastructure-config.json
4. Create images pipelines

### Phase 4: Test Integration
1. Build baseline in infrastructure repo
2. Build team images in images repo
3. Verify cross-repo communication
4. Test sync-definitions-and-pools.yml

### Phase 5: Cutover
1. Archive old single repo
2. Update documentation
3. Train teams on new model
4. Monitor for issues

---

## ✅ Summary

**Two repositories with clear separation:**
- **Infrastructure Repo:** Ops team, deployed rarely, controls baseline
- **Images Repo:** Dev teams, deployed continuously, builds team images

**Key principles:**
- 🔐 Security through separation
- 🚀 Agility through independence
- 📊 Clarity through ownership
- 🔄 Integration through manifests

**Next steps:**
1. Create updated pipelines for each repo
2. Design infrastructure-config.json schema
3. Set up cross-repo notifications
4. Document developer workflows
