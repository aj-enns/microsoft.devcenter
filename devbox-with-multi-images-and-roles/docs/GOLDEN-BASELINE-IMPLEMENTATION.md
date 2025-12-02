# Golden Security Baseline Image - Implementation Guide

## Overview

This implementation uses **Packer Template Composition** to create an immutable security baseline that prevents developers from bypassing security requirements. This is the **strongest** enforcement mechanism available.

## How It Works

### The Problem We Solved

**Before:** Team templates copied security provisioners inline, allowing developers to:
- Delete or comment out security configurations
- Disable Windows Defender, UAC, Firewall
- Remove Azure AD join requirements
- Bypass audit logging

**After:** Team templates MUST build from a golden baseline image:
- Security configurations are "baked into" the base image
- Developers cannot access or modify baseline security
- Teams only add their software on top of the secure foundation
- Multiple enforcement layers prevent bypass attempts

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     MICROSOFT BASE IMAGE                        │
│               Windows 11 Enterprise + M365                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│              SECURITYBASELINEIMAGE (Operations)                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ ✓ Azure AD Join Readiness     ✓ Compliance Tools         │ │
│  │ ✓ Windows Defender Enabled    ✓ Audit & Logging          │ │
│  │ ✓ Windows Firewall Enabled    ✓ PowerShell Logging       │ │
│  │ ✓ UAC Enabled                 ✓ Event Log Configuration  │ │
│  └───────────────────────────────────────────────────────────┘ │
│                     IMMUTABLE - CANNOT MODIFY                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  VSCodeDev  │  │   JavaDev   │  │  .NETDev    │
│    Image    │  │    Image    │  │    Image    │
├─────────────┤  ├─────────────┤  ├─────────────┤
│ + VS Code   │  │ + IntelliJ  │  │ + VS 2022   │
│ + Node.js   │  │ + Maven     │  │ + Rider     │
│ + Python    │  │ + Gradle    │  │ + SQL Srvr  │
│ + Docker    │  │ + Tomcat    │  │ + Azure SDK │
└─────────────┘  └─────────────┘  └─────────────┘
  (Dev Team)       (Dev Team)       (Dev Team)
```

## Enforcement Layers

### Layer 1: Image Composition (Strongest)
- **SecurityBaselineImage** contains all security configs
- Baked into the image during Operations Team build
- Team templates use this as source (not Microsoft base)
- **Result:** Developers literally cannot access baseline provisioners

### Layer 2: CODEOWNERS Protection
```
/images/packer/base/  @operations-team
```
- Base image folder requires Operations approval
- Pull requests modifying baseline blocked without Ops review
- **Result:** Baseline changes require authorized approval

### Layer 3: CI/CD Validation
- Validates team templates reference `SecurityBaselineImage`
- Blocks PRs that try to use Microsoft base directly
- Scans for security-disabling patterns
- Validates Packer syntax
- **Result:** Automated enforcement before merge

### Layer 4: Runtime Validation
- Team templates include security validation checks
- Verify UAC, Defender, Firewall still enabled
- Fails build if security baseline compromised
- **Result:** Build-time verification before deployment

### Layer 5: Azure Policy (Optional)
- Require Intune enrollment at Azure level
- Conditional Access policies
- Device compliance requirements
- **Result:** Runtime enforcement on deployed Dev Boxes

## File Structure

```
images/
├── packer/
│   ├── base/                                    (Operations Team Only)
│   │   ├── security-baseline.pkr.hcl           # Golden image template
│   │   ├── security-baseline.pkrvars.hcl.example
│   │   └── build-baseline-image.ps1            # Build automation
│   │
│   └── teams/                                   (Development Teams)
│       ├── vscode-devbox.pkr.hcl               # Builds FROM baseline
│       └── vscode-variables.pkrvars.hcl.example
│
├── definitions/
│   └── devbox-definitions.json                 # Pool configurations
│
└── CODEOWNERS                                   # Approval requirements

.github/workflows/
└── validate-devbox-images.yml                   # CI/CD enforcement
```

## Step-by-Step Implementation

### Phase 1: Operations Team - Build Golden Baseline

#### 1.1 Create Variables File

```powershell
cd terraform/devbox-with-multi-images-and-roles/images/packer/base
cp security-baseline.pkrvars.hcl.example security-baseline.pkrvars.hcl
```

Edit `security-baseline.pkrvars.hcl`:
```hcl
subscription_id     = "your-subscription-id"
resource_group_name = "rg-devcenter-gallery"
gallery_name        = "galdevboxshared"
image_version       = "1.0.0"
location            = "eastus"
```

#### 1.2 Build Baseline Image

```powershell
# Validate template first
.\build-baseline-image.ps1 -ImageVersion "1.0.0" -ValidateOnly

# Build the image (takes ~45-60 minutes)
.\build-baseline-image.ps1 -ImageVersion "1.0.0"
```

The script will:
1. ✓ Check prerequisites (Packer, Azure CLI, authentication)
2. ✓ Initialize Packer plugins
3. ✓ Validate template syntax
4. ✓ Build SecurityBaselineImage in Azure Compute Gallery
5. ✓ Run security validation checks
6. ✓ Generate manifest file

#### 1.3 Verify Baseline Image

```powershell
# Check image exists in gallery
az sig image-version list `
  --gallery-name galdevboxshared `
  --gallery-image-definition SecurityBaselineImage `
  --resource-group rg-devcenter-gallery `
  --query "[].{Version:name, State:provisioningState}" -o table
```

Expected output:
```
Version    State
---------  ---------
1.0.0      Succeeded
```

### Phase 2: Development Teams - Build Custom Images

#### 2.1 Create Team Variables File

```powershell
cd terraform/devbox-with-multi-images-and-roles/images/packer/teams
cp vscode-variables.pkrvars.hcl.example vscode-variables.pkrvars.hcl
```

Edit `vscode-variables.pkrvars.hcl`:
```hcl
subscription_id        = "your-subscription-id"
resource_group_name    = "rg-devcenter-gallery"
gallery_name           = "galdevboxshared"
baseline_image_version = "1.0.0"          # ← MUST match baseline version
image_version          = "1.0.0"           # Team image version
location               = "eastus"
```

**CRITICAL:** `baseline_image_version` must reference an existing SecurityBaselineImage version.

#### 2.2 Build Team Image

```powershell
# Initialize Packer
packer init vscode-devbox.pkr.hcl

# Validate template
packer validate -var-file="vscode-variables.pkrvars.hcl" vscode-devbox.pkr.hcl

# Build the image (takes ~30-40 minutes)
packer build -var-file="vscode-variables.pkrvars.hcl" vscode-devbox.pkr.hcl
```

#### 2.3 Verify Team Image

```powershell
az sig image-version list `
  --gallery-name galdevboxshared `
  --gallery-image-definition VSCodeDevImage `
  --resource-group rg-devcenter-gallery `
  --query "[].{Version:name, State:provisioningState}" -o table
```

### Phase 3: Configure Branch Protection & CI/CD

#### 3.1 Enable Branch Protection (GitHub)

Repository Settings → Branches → Add Rule:
- Branch name pattern: `main`
- ☑ Require pull request reviews before merging
- ☑ Require review from Code Owners
- ☑ Require status checks to pass before merging
  - Select: `Ensure SecurityBaselineImage Usage`
  - Select: `Scan for Dangerous Patterns`
  - Select: `Validate Packer Syntax`
- ☑ Require conversation resolution before merging
- ☑ Do not allow bypassing the above settings

#### 3.2 Verify CI/CD Workflow

The workflow file is already in place:
```
.github/workflows/validate-devbox-images.yml
```

Test it by creating a PR that modifies a team image template.

### Phase 4: Update Existing Team Templates

If you have existing team templates that build directly from Microsoft base:

#### 4.1 Update Source Block

**Before (vulnerable):**
```hcl
source "azure-arm" "team_image" {
  # Builds directly from Microsoft base - CAN BYPASS SECURITY
  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "windows-ent-cpc"
  image_sku       = "win11-24h2-ent-cpc-m365"
  # ... other config ...
}
```

**After (secure):**
```hcl
source "azure-arm" "team_image" {
  # Builds from SecurityBaselineImage - CANNOT BYPASS SECURITY
  os_type = "Windows"
  
  shared_image_gallery {
    subscription   = var.subscription_id
    resource_group = var.resource_group_name
    gallery_name   = var.gallery_name
    image_name     = "SecurityBaselineImage"
    image_version  = var.baseline_image_version
  }
  # ... other config ...
}
```

#### 4.2 Remove Inline Security Provisioners

**Delete these from team templates** (they're in the baseline now):
- ❌ Azure AD readiness configuration
- ❌ Windows Defender enablement
- ❌ Windows Firewall configuration
- ❌ UAC settings
- ❌ PowerShell logging setup
- ❌ Azure CLI installation

**Keep only team-specific customizations:**
- ✓ Development tools (VS Code, IDEs)
- ✓ Language runtimes (Node.js, Python, .NET)
- ✓ Team-specific software
- ✓ Custom configurations

#### 4.3 Add Security Validation

Add this provisioner to verify baseline is intact:
```hcl
provisioner "powershell" {
  inline = [
    "Write-Host '=== Verifying Security Baseline ==='",
    "$errors = @()",
    
    # Check UAC
    "$uac = Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA'",
    "if ($uac.EnableLUA -ne 1) { $errors += 'UAC disabled' }",
    
    # Check Defender
    "$defender = Get-MpPreference",
    "if ($defender.DisableRealtimeMonitoring -eq $true) { $errors += 'Defender disabled' }",
    
    # Check Firewall
    "$fw = Get-NetFirewallProfile | Where-Object { $_.Enabled -eq $false }",
    "if ($fw.Count -gt 0) { $errors += 'Firewall disabled' }",
    
    # Fail build if issues found
    "if ($errors.Count -gt 0) {",
    "  foreach ($error in $errors) { Write-Host \"✗ $error\" -ForegroundColor Red }",
    "  throw 'Security validation failed'",
    "}",
    "Write-Host '✓ Security baseline intact' -ForegroundColor Green"
  ]
}
```

## Testing the Enforcement

### Test 1: Try to Bypass Security (Should Fail)

Create a test branch and modify a team template to use Microsoft base directly:

```hcl
# This SHOULD be blocked by CI/CD
source "azure-arm" "test" {
  image_publisher = "MicrosoftWindowsDesktop"  # ← Bypass attempt
  image_offer     = "windows-ent-cpc"
  image_sku       = "win11-24h2-ent-cpc-m365"
}
```

Create a PR. **Expected result:** CI/CD fails with:
```
✗ ERROR: References Microsoft base image directly
  This bypasses security baseline. Use SecurityBaselineImage instead.
```

### Test 2: Try to Disable Security (Should Fail)

Add this to a team template:

```hcl
# This SHOULD be blocked by CI/CD
provisioner "powershell" {
  inline = [
    "Set-MpPreference -DisableRealtimeMonitoring $true"  # ← Disable Defender
  ]
}
```

Create a PR. **Expected result:** CI/CD fails with:
```
✗ SECURITY VIOLATION DETECTED!
  Pattern: DisableRealtimeMonitoring \$true
  Description: Disables Windows Defender real-time protection
```

### Test 3: Valid Team Customization (Should Pass)

Add team software (doesn't touch security):

```hcl
provisioner "powershell" {
  inline = [
    "choco install -y vscode",
    "choco install -y nodejs"
  ]
}
```

Create a PR. **Expected result:** ✓ All checks pass, PR can be merged.

## Updating the Baseline Image

When Operations needs to update security configurations:

### 1. Update Baseline Template

Edit `packer/base/security-baseline.pkr.hcl` to add new security features.

### 2. Increment Version

Decide on version increment:
- **Major (2.0.0):** Breaking changes requiring team image rebuilds
- **Minor (1.1.0):** New security features, backward compatible
- **Patch (1.0.1):** Bug fixes, no functional changes

### 3. Build New Version

```powershell
.\build-baseline-image.ps1 -ImageVersion "1.1.0"
```

### 4. Notify Development Teams

Send notification:
```
SecurityBaselineImage v1.1.0 is now available!

New features:
- Enhanced PowerShell logging
- Additional compliance tools
- Performance optimizations

Action required:
1. Update your variables file: baseline_image_version = "1.1.0"
2. Rebuild your team images
3. Update DevBox definitions to use new versions
```

### 5. Teams Rebuild Images

Each team updates their `baseline_image_version` and rebuilds:

```powershell
# Update vscode-variables.pkrvars.hcl
baseline_image_version = "1.1.0"
image_version          = "1.1.0"  # Also increment team version

# Rebuild
packer build -var-file="vscode-variables.pkrvars.hcl" vscode-devbox.pkr.hcl
```

## Troubleshooting

### Issue: "Image SecurityBaselineImage not found"

**Cause:** Baseline image not built yet or wrong gallery/resource group.

**Solution:**
```powershell
# Verify baseline exists
az sig image-definition show `
  --gallery-name galdevboxshared `
  --gallery-image-definition SecurityBaselineImage `
  --resource-group rg-devcenter-gallery

# If not found, build it first
cd images/packer/base
.\build-baseline-image.ps1 -ImageVersion "1.0.0"
```

### Issue: "Image version 1.0.0 not found"

**Cause:** Version mismatch between team template and available baseline versions.

**Solution:**
```powershell
# Check available versions
az sig image-version list `
  --gallery-name galdevboxshared `
  --gallery-image-definition SecurityBaselineImage `
  --resource-group rg-devcenter-gallery

# Update your variables file to match an existing version
```

### Issue: CI/CD fails with "Does NOT reference SecurityBaselineImage"

**Cause:** Team template still using Microsoft base image directly.

**Solution:** Update source block to use `shared_image_gallery` pointing to SecurityBaselineImage.

### Issue: Security validation fails during team image build

**Cause:** Team provisioners accidentally disabled security features.

**Solution:** Review recent changes to team template. Remove any commands that modify:
- UAC settings (`EnableLUA`)
- Windows Defender (`Set-MpPreference`)
- Windows Firewall (`Set-NetFirewallProfile`)
- Audit logging (`auditpol`)

## Benefits Summary

✅ **Immutable Security:** Baseline configurations cannot be modified by dev teams  
✅ **Defense in Depth:** 5 enforcement layers prevent bypass attempts  
✅ **Clear Separation:** Operations owns security, teams own software  
✅ **Automated Enforcement:** CI/CD validates every change  
✅ **Faster Team Builds:** Teams only install their tools (not full security stack)  
✅ **Audit Trail:** All changes tracked via Git and CODEOWNERS approvals  
✅ **Version Control:** Track baseline versions, roll back if needed  
✅ **Consistent Security:** All Dev Boxes have identical security foundation  

## Next Steps

1. ✅ Build SecurityBaselineImage v1.0.0 (Operations Team)
2. ✅ Update team templates to reference baseline
3. ✅ Enable branch protection rules
4. ✅ Test enforcement with bypass attempts
5. ✅ Rebuild all team images from baseline
6. ✅ Update DevBox definitions
7. ✅ Deploy to production
8. ✅ Train teams on new workflow
9. ✅ Document in team wikis

## Additional Resources

- [Packer Documentation](https://www.packer.io/docs)
- [Azure Compute Gallery](https://learn.microsoft.com/azure/virtual-machines/shared-image-galleries)
- [DevBox Security Best Practices](https://learn.microsoft.com/azure/dev-box/concept-dev-box-security)
- [Windows Security Baselines](https://learn.microsoft.com/windows/security/threat-protection/windows-security-baselines)
