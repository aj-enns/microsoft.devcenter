# 🚀 DevBox Multi-Role Deployment Checklist

This checklist ensures a smooth deployment without debugging issues.

## Prerequisites

- [ ] Azure CLI installed and authenticated (`az login`)
- [ ] Terraform installed (>= 1.0)
- [ ] PowerShell 7+ installed
- [ ] Contributor access to Azure subscription
- [ ] User Principal ID for DevBox access

## Infrastructure Deployment

### Step 1: Configure Variables

```powershell
cd terraform/devbox-with-multi-images-and-roles/infrastructure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

**Required values:**
- `location` - Azure region (e.g., "canadacentral")
- `user_principal_id` - Your Azure AD user/group ID
- `enable_nat_gateway = true` - Required for internet access

### Step 2: Deploy Infrastructure

```powershell
terraform init
terraform plan
terraform apply
```

**Expected time:** 5-10 minutes

**Verify:**
- DevCenter created
- Project created with `maximum_dev_boxes_per_user = 10`
- Compute Gallery created
- User-assigned managed identity created
- Virtual network with NAT gateway created

### Step 3: Verify Network Connection

```powershell
cd scripts
.\02-attach-networks.ps1
```

**Expected:** Health check shows "Passed" (may take 5-10 minutes)

## Baseline Image Build

### Step 4: Create Baseline Image Definition

```powershell
cd ../../images/packer/base
.\create-image-definition.ps1 -ResourceGroup <rg-name> -GalleryName <gallery-name>
```

**Run once only** - Creates SecurityBaselineImage definition in gallery

### Step 5: Build Baseline Image

```powershell
.\build-baseline-image.ps1 -ImageVersion "1.0.0"
```

**Expected time:** 45-60 minutes

**Verify:** Image appears in Compute Gallery with State=Succeeded

## Team Image Setup

### Step 6: Create Team Image Definitions

```powershell
cd ../teams

# For each team
.\create-image-definition.ps1 -ImageType vscode -ResourceGroup <rg-name> -GalleryName <gallery-name>
```

**Run once per image type**

### Step 7: Development Teams Build Images

Development teams use their own build scripts (example: VSCode team):

```powershell
# In images/packer/teams directory
.\build-image.ps1 -ImageType vscode -ImageVersion "1.0.0"
```

**Expected time:** 30-45 minutes per team image

## DevCenter Configuration

### Step 8: Verify Gallery Sync ⏱️ CRITICAL

```powershell
cd ../../../../infrastructure/scripts
.\00-verify-gallery-sync.ps1
```

**IMPORTANT:** Custom images take **5-30 minutes** to sync from Compute Gallery to DevCenter after they're built.

**Run this script periodically until it shows:**
```
✓ Found 2 custom image(s) synced:
  • SecurityBaselineImage
  • VSCodeDevImage
```

**Do NOT proceed** until images appear in DevCenter!

### Step 9: Create DevBox Definitions

Once images are synced:

```powershell
.\03-create-definitions.ps1
```

**Verify:** Definitions appear in DevCenter under Project → Image definitions

### Step 10: Create DevBox Pools

```powershell
.\04-sync-pools.ps1
```

**Verify:** Pools appear in Azure Portal under Project → Dev box pools

## User Access

### Step 11: Test Dev Box Provisioning

1. Navigate to https://devportal.microsoft.com
2. Select project
3. Choose a pool (e.g., "VSCode-Development-Pool")
4. Create Dev Box

**Expected time:** 20-30 minutes for first provision

## Common Issues & Fixes

### ❌ "Gallery not attached" or "Images not syncing"

**Cause:** User-assigned managed identity needs Contributor role on gallery

**Fix:** Terraform now handles this automatically. If issues persist:

```powershell
# Get identity principal ID
$outputs = terraform output -json | ConvertFrom-Json
$principalId = $outputs.managed_identity_principal_id.value

# Grant Contributor role
az role assignment create \
  --assignee $principalId \
  --role "Contributor" \
  --scope <compute-gallery-resource-id>

# Wait 2 minutes, then recreate gallery attachment
```

### ❌ "0 dev boxes per user" limit

**Cause:** Project needs `maximum_dev_boxes_per_user` configured

**Fix:** Already set to 10 in Terraform. If you need to change:
1. Edit `infrastructure/modules/devcenter/main.tf`
2. Update `maximum_dev_boxes_per_user = 10` value
3. Run `terraform apply`

### ❌ Scripts show empty values for DevCenter/ResourceGroup

**Cause:** Scripts running from wrong directory, can't find Terraform state

**Fix:** All scripts now automatically navigate to infrastructure directory. Ensure you run scripts from their original location in `infrastructure/scripts/`

### ❌ Pool creation fails: "state parameter not found"

**Cause:** Azure CLI parameter is `status=` not `state=`

**Fix:** Already corrected in 04-sync-pools.ps1

### ❌ Custom images not appearing in DevCenter

**Cause:** Gallery sync takes time (5-30 minutes)

**Fix:** Run `.\00-verify-gallery-sync.ps1` periodically. Wait until images show as synced before creating definitions.

## Post-Deployment

- [ ] Verify users can access https://devportal.microsoft.com
- [ ] Test Dev Box provisioning from each pool
- [ ] Configure Intune policies (optional): `.\03-configure-intune.ps1`
- [ ] Set up monitoring and alerts
- [ ] Document any customizations in your organization

## Success Criteria

✅ DevCenter operational with project  
✅ Network connection health check passed  
✅ Baseline image built and in gallery  
✅ Team images built and synced to DevCenter  
✅ DevBox definitions created  
✅ DevBox pools created  
✅ Users can provision Dev Boxes from portal  

**Deployment Complete! 🎉**

## Support

- **Terraform errors:** Check `infrastructure/README.md` troubleshooting section
- **Packer build issues:** Check `images/README.md` troubleshooting section
- **Azure DevCenter:** https://learn.microsoft.com/azure/dev-box/

---

**Last Updated:** 2025-11-18  
**Tested With:** Azure CLI 2.77.0, Terraform 1.x, Packer 1.14.2
