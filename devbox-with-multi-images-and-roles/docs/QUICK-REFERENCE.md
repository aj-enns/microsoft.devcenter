# 🚀 Quick Reference - Golden Baseline Security

## TL;DR - What Changed?

**Old Way (Vulnerable):**
- Team templates contained all security configs
- Developers could delete/modify security settings
- No enforcement preventing bypass

**New Way (Enforced):**
- Operations builds `SecurityBaselineImage` with all security
- Teams build FROM that baseline (cannot modify it)
- 5 enforcement layers prevent any bypass attempts

---

## Quick Commands

### Operations Team - Build Baseline

```powershell
# Navigate to base folder
cd terraform/devbox-with-multi-images-and-roles/images/packer/base

# Copy variables file
cp security-baseline.pkrvars.hcl.example security-baseline.pkrvars.hcl

# Edit with your Azure details (subscription, gallery, resource group)
notepad security-baseline.pkrvars.hcl

# Build baseline image (45-60 min)
.\build-baseline-image.ps1 -ImageVersion "1.0.0"

# Verify it exists
az sig image-version list `
  --gallery-name <your-gallery> `
  --gallery-image-definition SecurityBaselineImage `
  --resource-group <your-rg> `
  -o table
```

### Development Teams - Build Custom Image

```powershell
# Navigate to teams folder
cd terraform/devbox-with-multi-images-and-roles/images/packer/teams

# Copy variables file
cp vscode-variables.pkrvars.hcl.example vscode-variables.pkrvars.hcl

# Edit with your Azure details AND baseline version
notepad vscode-variables.pkrvars.hcl
# ⚠️ IMPORTANT: Set baseline_image_version = "1.0.0"

# Initialize Packer
packer init vscode-devbox.pkr.hcl

# Build team image (30-40 min)
packer build -var-file="vscode-variables.pkrvars.hcl" vscode-devbox.pkr.hcl

# Verify it exists
az sig image-version list `
  --gallery-name <your-gallery> `
  --gallery-image-definition VSCodeDevImage `
  --resource-group <your-rg> `
  -o table
```

---

## What You Need to Know

### If You're on the Operations Team 👷

**Your responsibility:**
- Build and maintain `SecurityBaselineImage`
- Update when security requirements change
- Approve any changes to `packer/base/` folder

**Key files you control:**
- `images/packer/base/security-baseline.pkr.hcl`
- `images/packer/base/build-baseline-image.ps1`

**When to rebuild:**
- Security policy changes
- New compliance requirements
- Windows updates require new features
- Quarterly (recommended)

### If You're on a Development Team 👨‍💻

**Your responsibility:**
- Build team-specific images FROM SecurityBaselineImage
- Add your development tools
- Test your images work correctly

**Key files you control:**
- `images/packer/teams/<your-team>-devbox.pkr.hcl`
- `images/packer/teams/<your-team>-variables.pkrvars.hcl`

**What you CAN do:**
- ✅ Install any development software
- ✅ Configure development tools
- ✅ Add VS Code extensions
- ✅ Set up language runtimes

**What you CANNOT do:**
- ❌ Modify security baseline configurations
- ❌ Disable Windows Defender
- ❌ Turn off Windows Firewall
- ❌ Disable UAC
- ❌ Use Microsoft base image directly

---

## The 5 Enforcement Layers

### 1️⃣ Image Composition (Strongest)
Security is in base image → Teams build on top → Cannot modify base

### 2️⃣ CODEOWNERS
`/packer/base/` requires @operations-team approval

### 3️⃣ CI/CD Validation
Automated checks block bypass attempts in PRs

### 4️⃣ Build-Time Validation
Templates verify security still intact during build

### 5️⃣ Runtime Enforcement
Azure Policy + Intune verify compliance

---

## Common Scenarios

### Scenario: Operations updates security baseline

```powershell
# 1. Operations updates security-baseline.pkr.hcl
# 2. Operations builds new version
.\build-baseline-image.ps1 -ImageVersion "1.1.0"

# 3. Notify teams: "v1.1.0 available, please rebuild"
# 4. Teams update their variables files
baseline_image_version = "1.1.0"

# 5. Teams rebuild their images
packer build -var-file="vscode-variables.pkrvars.hcl" vscode-devbox.pkr.hcl
```

### Scenario: New team needs a custom image

```powershell
# 1. Copy existing team template as starting point
cd images/packer/teams
cp vscode-devbox.pkr.hcl java-devbox.pkr.hcl
cp vscode-variables.pkrvars.hcl.example java-variables.pkrvars.hcl.example

# 2. Customize for your team (keep SecurityBaselineImage source!)
# 3. Update CODEOWNERS to add your team
/packer/teams/java* @java-team-leads

# 4. Build your image
packer build -var-file="java-variables.pkrvars.hcl" java-devbox.pkr.hcl
```

### Scenario: Developer tries to bypass security

```powershell
# Developer edits template to disable Defender
provisioner "powershell" {
  inline = ["Set-MpPreference -DisableRealtimeMonitoring $true"]
}

# Result:
# ❌ CI/CD catches dangerous pattern
# ❌ PR check fails
# ❌ Cannot merge without removing the command
```

---

## Troubleshooting Quick Fixes

### "Image SecurityBaselineImage not found"
```powershell
# Check if baseline exists
az sig image-definition show `
  --gallery-name <gallery> `
  --gallery-image-definition SecurityBaselineImage `
  --resource-group <rg>

# If not found, Operations team needs to build it
cd images/packer/base
.\build-baseline-image.ps1 -ImageVersion "1.0.0"
```

### "Image version X.X.X not found"
```powershell
# Check what versions exist
az sig image-version list `
  --gallery-name <gallery> `
  --gallery-image-definition SecurityBaselineImage `
  --resource-group <rg>

# Update your variables file to match an existing version
baseline_image_version = "1.0.0"  # Use actual version from above
```

### "CI/CD fails: Does not reference SecurityBaselineImage"
```hcl
# Fix your source block:
shared_image_gallery {
  gallery_name  = var.gallery_name
  image_name    = "SecurityBaselineImage"  # ← Must have this
  image_version = var.baseline_image_version
}

# Remove any direct Microsoft base references:
# ❌ image_publisher = "MicrosoftWindowsDesktop"
# ❌ image_offer     = "windows-ent-cpc"
# ❌ image_sku       = "win11-24h2-ent-cpc-m365"
```

---

## File Locations Cheat Sheet

```
terraform/devbox-with-multi-images-and-roles/
│
├── images/packer/
│   ├── base/                                    ← Operations only
│   │   ├── security-baseline.pkr.hcl           ← Golden image
│   │   └── build-baseline-image.ps1            ← Build script
│   │
│   └── teams/                                   ← Dev teams
│       ├── vscode-devbox.pkr.hcl               ← Team image
│       └── vscode-variables.pkrvars.hcl        ← Team config
│
├── .github/workflows/
│   └── validate-devbox-images.yml               ← CI/CD checks
│
├── SECURITY-ENFORCEMENT-SUMMARY.md              ← Read this first!
├── GOLDEN-BASELINE-IMPLEMENTATION.md            ← Full guide
└── INDEX.md                                     ← Documentation hub
```

---

## Need More Info?

| Question | Document |
|----------|----------|
| How does security enforcement work? | [SECURITY-ENFORCEMENT-SUMMARY.md](SECURITY-ENFORCEMENT-SUMMARY.md) |
| How do I implement this step-by-step? | [GOLDEN-BASELINE-IMPLEMENTATION.md](GOLDEN-BASELINE-IMPLEMENTATION.md) |
| What's the overall architecture? | [ARCHITECTURE.md](ARCHITECTURE.md) |
| Quick setup for either team? | [QUICKSTART.md](QUICKSTART.md) |
| Complete reference guide? | [README.md](README.md) |
| Where do I start? | [INDEX.md](INDEX.md) |

---

## Key Takeaway

> **Developers cannot bypass security because they don't have access to the security configurations - they're baked into an immutable base image that Operations controls.**

Think of it like:
- 🏗️ Operations builds the foundation with security
- 🎨 Developers decorate the house with their tools
- 🚫 Developers cannot demolish the foundation

It's not a policy. It's not a request. It's technically enforced at multiple layers.
