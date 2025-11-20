# DevBox Infrastructure Scripts - Enhanced Workflow

## Overview

These scripts have been enhanced to be **smarter and less brittle** by:
- ✅ Auto-validating SKU names against Azure's available SKUs
- ✅ Auto-correcting storage type mismatches
- ✅ Checking image availability before attempting to create definitions
- ✅ Providing actionable error messages with fix suggestions
- ✅ Detecting orphaned pool references

## Script Execution Order

### 1. **00-validate-definitions.ps1** (NEW!)
**Purpose:** Validate configuration before deployment

```powershell
.\00-validate-definitions.ps1
```

**What it checks:**
- ✓ SKU names are valid
- ✓ Storage types match SKU specifications
- ✓ Images exist in the gallery
- ✓ Pool references point to defined definitions

**Auto-fix option:**
```powershell
.\00-validate-definitions.ps1 -Fix
```
This automatically corrects storage type mismatches (e.g., `ssd_256gb` → `ssd_512gb` when SKU requires it).

### 2. **03-create-definitions.ps1** (ENHANCED!)
**Purpose:** Create DevBox definitions in DevCenter

```powershell
.\03-create-definitions.ps1
```

**Enhancements:**
- ✅ Loads all available SKUs and validates against them
- ✅ Auto-corrects storage types based on SKU requirements
- ✅ Detects invalid SKUs and provides guidance
- ✅ Shows detailed error messages with fix commands

**What changed:** Now checks SKU validity and auto-corrects storage mismatches instead of failing silently.

### 3. **04-sync-pools.ps1** (ENHANCED!)
**Purpose:** Create/sync DevBox pools

```powershell
.\04-sync-pools.ps1
```

**Enhancements:**
- ✅ Provides detailed guidance when definitions are missing
- ✅ Shows exact commands to check image availability
- ✅ Links definition config to missing images
- ✅ Summary shows missing vs available definitions

**What changed:** Instead of just saying "definition not found," it now tells you:
1. Which image is missing
2. How to check if the image exists
3. Exact steps to fix the issue

## Common Issues and Auto-Fixes

### Issue #1: Storage Type Mismatch
**Problem:**
```json
{
  "computeSku": "general_i_16c64gb512ssd_v2",
  "storageType": "ssd_256gb"  // ❌ Mismatch!
}
```

**Auto-fix:**
```powershell
.\00-validate-definitions.ps1 -Fix
```
Automatically changes `storageType` to `"ssd_512gb"` to match the SKU.

**Manual fix in devbox-definitions.json:**
```json
{
  "computeSku": "general_i_16c64gb512ssd_v2",
  "storageType": "ssd_512gb"  // ✅ or "ssd"
}
```

### Issue #2: Invalid SKU Name
**Problem:**
```json
{
  "computeSku": "general_i_16c64gb512_v2"  // ❌ Missing "ssd"
}
```

**Fix:** Validation script shows all available SKUs:
```powershell
az devcenter admin sku list --query '[].name' -o table
```

Common valid SKUs:
- `general_i_8c32gb256ssd_v2`
- `general_i_16c64gb512ssd_v2`
- `general_i_16c64gb1024ssd_v2`
- `general_i_32c128gb512ssd_v2`

### Issue #3: Missing Image
**Problem:** Pool references a definition, but the image doesn't exist in the gallery.

**Detection:**
```powershell
.\00-validate-definitions.ps1
# Shows: ✗ DotNet-DevBox: Image 'DotNetDevImage' not found in gallery
```

**Fix Steps:**
1. Build the image using Packer:
   ```powershell
   cd ../../images/packer
   .\build-image.ps1 -ImageType dotnet
   ```

2. Re-run validation:
   ```powershell
   .\00-validate-definitions.ps1
   ```

3. Create definition:
   ```powershell
   .\03-create-definitions.ps1
   ```

## Recommended Workflow

### For New Images

1. **Build the image** (from `images/packer/`):
   ```powershell
   .\build-image.ps1 -ImageType java
   ```

2. **Validate configuration** (from `infrastructure/scripts/`):
   ```powershell
   .\00-validate-definitions.ps1 -Fix
   ```

3. **Create definition**:
   ```powershell
   .\03-create-definitions.ps1
   ```

4. **Sync pools**:
   ```powershell
   .\04-sync-pools.ps1
   ```

### For Configuration Changes

1. **Edit** `images/definitions/devbox-definitions.json`

2. **Validate changes**:
   ```powershell
   .\00-validate-definitions.ps1
   ```

3. **If validation passes**, deploy:
   ```powershell
   .\03-create-definitions.ps1
   .\04-sync-pools.ps1
   ```

## What Makes These Scripts "Smart"?

### Before (Brittle)
- ❌ Failed with cryptic Azure API errors
- ❌ No pre-validation
- ❌ Silently skipped issues
- ❌ Required manual SKU lookup
- ❌ No guidance on fixing errors

### After (Smart)
- ✅ Validates SKUs against Azure's API
- ✅ Auto-corrects common misconfigurations
- ✅ Provides actionable error messages
- ✅ Shows exact fix commands
- ✅ Pre-flight validation before deployment
- ✅ Links errors to specific definitions/pools

## Troubleshooting

### "SKU not found" error
```powershell
# List all available SKUs
az devcenter admin sku list --query '[].{Name:name, vCPUs:capabilities[?name==`vCPUs`].value | [0], RAM:capabilities[?name==`MemoryGB`].value | [0]}' -o table
```

### "Image not found" error
```powershell
# List images in gallery
az sig image-definition list --gallery-name <gallery-name> --resource-group <rg-name> --query '[].name' -o table

# Check specific image versions
az sig image-version list --gallery-name <gallery-name> --resource-group <rg-name> --gallery-image-definition JavaDevImage -o table
```

### "Definition already exists" warning
This is normal - the script skips existing definitions to avoid conflicts. To update an existing definition, either:
- Delete it first: `az devcenter admin devbox-definition delete --name <name> ...`
- Or modify its version in the definitions file

## Files Modified

- ✅ `00-validate-definitions.ps1` - NEW validation script
- ✅ `03-create-definitions.ps1` - Added SKU validation and auto-correction
- ✅ `04-sync-pools.ps1` - Added better error messages and guidance
- ✅ `../../images/definitions/devbox-definitions.json` - Auto-corrected storage types

## Questions?

- **Where do I find valid SKU names?** Run `az devcenter admin sku list -o table`
- **How do I know what storage type to use?** Use `"ssd"` or match the GB in the SKU name (e.g., `512ssd` → `"ssd_512gb"`)
- **Can I use a different storage size than the SKU?** No, Azure DevBox requires storage to match the SKU
- **What if validation passes but creation fails?** Check Azure RBAC permissions and that the image is in the "Succeeded" state
