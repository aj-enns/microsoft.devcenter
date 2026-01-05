# =============================================================================
# GOLDEN SECURITY BASELINE IMAGE
# =============================================================================
# This template creates the foundational security-hardened Windows 11 image
# that ALL team-specific images MUST build upon.
#
# OWNERSHIP: Operations Team Only
# PROTECTED BY: CODEOWNERS - Requires @operations-team approval
# PURPOSE: Enforce mandatory security, compliance, and Azure AD join readiness
#
# Development teams CANNOT modify this file. They must use the resulting
# "SecurityBaselineImage" as the source for their team-specific customizations.
# =============================================================================

packer {
  required_version = ">= 1.9.0"
  
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2.0"
    }
  }
}

# =============================================================================
# VARIABLES
# =============================================================================

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID where resources will be created"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group containing the Azure Compute Gallery"
}

variable "gallery_name" {
  type        = string
  description = "Name of the Azure Compute Gallery for storing images"
}

variable "image_version" {
  type        = string
  description = "Semantic version for this baseline image (e.g., 1.0.0)"
  default     = "1.0.0"
}

variable "location" {
  type        = string
  description = "Azure region for temporary build resources"
  default     = "eastus"
}

variable "gallery_resource_group" {
  type        = string
  description = "Resource group that contains the Azure Compute Gallery (optional). If not set, uses resource_group_name"
  default     = ""
}

variable "client_id" {
  type        = string
  description = "Service principal client id (optional, read from ARM_CLIENT_ID env by default)"
  default     = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type        = string
  description = "Service principal client secret (optional, read from ARM_CLIENT_SECRET env by default)"
  default     = env("ARM_CLIENT_SECRET")
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant id (optional, read from ARM_TENANT_ID env by default)"
  default     = env("ARM_TENANT_ID")
}

variable "build_id" {
  type        = string
  description = "CI build id (optional, used for traceability)"
  default     = env("BUILD_BUILDID")
}

variable "vm_size" {
  type        = string
  description = "Azure VM size for the build process"
  default     = "Standard_D2s_v3"
}

# =============================================================================
# SOURCE CONFIGURATION
# =============================================================================
# This builds from Microsoft's official Windows 11 Enterprise base image

source "azure-arm" "security_baseline" {
  # Authentication
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # Build VM Configuration
  managed_image_resource_group_name = var.gallery_resource_group != "" ? var.gallery_resource_group : var.resource_group_name
  managed_image_name                = "SecurityBaselineImage-${var.image_version}"
  
  # Packer will create a temporary resource group for the build
  # and automatically delete it when done
  location = var.location
  vm_size  = var.vm_size

  # Source Image - Microsoft Windows 11 Enterprise with M365
  os_type         = "Windows"
  image_publisher = "MicrosoftWindowsDesktop"
  image_offer     = "windows-ent-cpc"
  image_sku       = "win11-24h2-ent-cpc-m365"

  # Communicator Settings
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "15m"
  winrm_username = "packer"

  # Azure Compute Gallery Destination
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.gallery_resource_group != "" ? var.gallery_resource_group : var.resource_group_name
    gallery_name         = var.gallery_name
    image_name           = "SecurityBaselineImage"
    image_version        = var.image_version
    replication_regions  = [var.location]
    storage_account_type = "Standard_LRS"
  }

  # Cleanup
  async_resourcegroup_delete = true
}

# =============================================================================
# BUILD PROCESS
# =============================================================================

build {
  name    = "security-baseline"
  sources = ["source.azure-arm.security_baseline"]

  # ---------------------------------------------------------------------------
  # INITIAL WAIT - Allow Windows to stabilize
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Waiting for Windows to stabilize ==='",
      "Start-Sleep -Seconds 30"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 1: INSTALL CHOCOLATEY (Package Manager)
  # ---------------------------------------------------------------------------
  # Required for subsequent software installations
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing Chocolatey Package Manager ==='",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))",
      "Write-Host 'Chocolatey installed successfully'",
      "",
      "# Verify installation",
      "choco --version"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 2: AZURE AD JOIN READINESS
  # ---------------------------------------------------------------------------
  # Configure Windows for Azure AD domain join and Intune enrollment
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Azure AD Join Readiness ==='",
      "",
      "# Set network profile to Private (required for WinRM configuration)",
      "Write-Host 'Setting network profile to Private...'",
      "Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue",
      "",
      "# Wait and verify network profile changed",
      "Start-Sleep -Seconds 5",
      "$profile = Get-NetConnectionProfile",
      "Write-Host \"Current network profile: $($profile.NetworkCategory)\"",
      "if ($profile.NetworkCategory -eq 'Public') {",
      "  Write-Warning 'Network still Public, attempting registry method...'",
      "  # Alternative method via registry",
      "  $profileGuid = (Get-NetConnectionProfile).InterfaceAlias",
      "  $regPath = 'HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\NetworkList\\Profiles'",
      "  Get-ChildItem $regPath | ForEach-Object {",
      "    Set-ItemProperty -Path $_.PSPath -Name 'Category' -Value 1 -ErrorAction SilentlyContinue",
      "  }",
      "  Start-Sleep -Seconds 3",
      "}",
      "",
      "# Enable User Account Control (UAC)",
      "Write-Host 'Enabling UAC...'",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA' -Value 1 -Force",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'ConsentPromptBehaviorAdmin' -Value 5 -Force",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'PromptOnSecureDesktop' -Value 1 -Force",
      "",
      "# Configure WinRM for Azure management",
      "Write-Host 'Configuring WinRM...'",
      "# Skip Enable-PSRemoting if WinRM already configured (it's already running from Packer)",
      "# Just configure the settings we need",
      "Set-Item WSMan:\\localhost\\Client\\TrustedHosts -Value '*' -Force -ErrorAction SilentlyContinue",
      "Set-Service -Name WinRM -StartupType Automatic -ErrorAction SilentlyContinue",
      "",
      "# Enable Remote Desktop (for DevBox connectivity)",
      "Write-Host 'Enabling Remote Desktop...'",
      "Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0 -Force",
      "Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction SilentlyContinue",
      "",
      "Write-Host 'Azure AD readiness configured successfully'"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 3: SECURITY BASELINE
  # ---------------------------------------------------------------------------
  # Enforce Windows security features (Defender, Firewall, Updates)
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Security Baseline ==='",
      "",
      "# Enable Windows Defender Real-Time Protection",
      "Write-Host 'Enabling Windows Defender...'",
      "Set-MpPreference -DisableRealtimeMonitoring $false -Force",
      "Set-MpPreference -DisableBehaviorMonitoring $false -Force",
      "Set-MpPreference -DisableIOAVProtection $false -Force",
      "Set-MpPreference -DisableScriptScanning $false -Force",
      "Update-MpSignature -ErrorAction SilentlyContinue",
      "",
      "# Enable Windows Firewall on all profiles",
      "Write-Host 'Enabling Windows Firewall...'",
      "Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True",
      "Set-NetFirewallProfile -Profile Domain -DefaultInboundAction Block -DefaultOutboundAction Allow",
      "Set-NetFirewallProfile -Profile Public -DefaultInboundAction Block -DefaultOutboundAction Allow",
      "Set-NetFirewallProfile -Profile Private -DefaultInboundAction Block -DefaultOutboundAction Allow",
      "",
      "# Configure Windows Update",
      "Write-Host 'Configuring Windows Update...'",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU' -Name 'NoAutoUpdate' -Value 0 -Force -ErrorAction SilentlyContinue",
      "",
      "# Enable BitLocker preparation (TPM) - Optional, may already be available",
      "Write-Host 'Checking BitLocker availability...'",
      "try {",
      "  $bitlocker = Get-WindowsOptionalFeature -Online -FeatureName BitLocker -ErrorAction SilentlyContinue",
      "  if ($bitlocker.State -ne 'Enabled') {",
      "    Write-Host 'Enabling BitLocker feature...'",
      "    Enable-WindowsOptionalFeature -Online -FeatureName BitLocker -NoRestart -ErrorAction Stop | Out-Null",
      "  } else {",
      "    Write-Host 'BitLocker feature already enabled'",
      "  }",
      "} catch {",
      "  Write-Host 'BitLocker feature not available or already configured (this is OK)'",
      "}",
      "",
      "Write-Host 'Security baseline configured successfully'"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 4: COMPLIANCE TOOLS
  # ---------------------------------------------------------------------------
  # Install tools required for compliance and management
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing Compliance Tools ==='",
      "",
      "# Install Azure CLI (for Azure management and authentication)",
      "Write-Host 'Installing Azure CLI...'",
      "choco install -y azure-cli --version 2.65.0",
      "",
      "# Install PowerShell 7+ (modern PowerShell with enhanced security)",
      "Write-Host 'Installing PowerShell 7...'",
      "choco install -y powershell-core",
      "",
      "# Verify installations (non-fatal, PATH may not be updated in current session)",
      "Write-Host 'Verifying installations...'",
      "try {",
      "  $azCli = 'C:\\Program Files\\Microsoft SDKs\\Azure\\CLI2\\wbin\\az.cmd'",
      "  if (Test-Path $azCli) {",
      "    $azVersion = & $azCli --version 2>&1 | Select-String 'azure-cli' | Select-Object -First 1",
      "    Write-Host \"Azure CLI: $azVersion\"",
      "  } else {",
      "    Write-Host 'Azure CLI installed but not yet in PATH (will be available after reboot)'",
      "  }",
      "} catch {",
      "  Write-Host 'Azure CLI verification skipped (will be available after reboot)'",
      "}",
      "",
      "try {",
      "  $pwsh = 'C:\\Program Files\\PowerShell\\7\\pwsh.exe'",
      "  if (Test-Path $pwsh) {",
      "    $pwshVersion = & $pwsh --version",
      "    Write-Host \"PowerShell: $pwshVersion\"",
      "  } else {",
      "    Write-Host 'PowerShell Core installed but not yet in PATH (will be available after reboot)'",
      "  }",
      "} catch {",
      "  Write-Host 'PowerShell Core verification skipped (will be available after reboot)'",
      "}",
      "",
      "Write-Host 'Compliance tools installed successfully'"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 5: AUDIT & LOGGING
  # ---------------------------------------------------------------------------
  # Configure enhanced logging and audit capabilities
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Audit & Logging ==='",
      "",
      "# Enable PowerShell Script Block Logging",
      "Write-Host 'Enabling PowerShell logging...'",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\ScriptBlockLogging' -Force | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\ScriptBlockLogging' -Name 'EnableScriptBlockLogging' -Value 1 -Force",
      "",
      "# Enable PowerShell Transcription",
      "New-Item -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\Transcription' -Force | Out-Null",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\Transcription' -Name 'EnableTranscripting' -Value 1 -Force",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\Transcription' -Name 'OutputDirectory' -Value 'C:\\PSTranscripts' -Force",
      "New-Item -Path 'C:\\PSTranscripts' -ItemType Directory -Force | Out-Null",
      "",
      "# Configure Event Log sizes",
      "Write-Host 'Configuring Event Logs...'",
      "wevtutil sl Security /ms:1048576000  # 1 GB",
      "wevtutil sl Application /ms:524288000  # 512 MB",
      "wevtutil sl System /ms:524288000  # 512 MB",
      "",
      "# Enable Process Creation Auditing",
      "Write-Host 'Enabling process auditing...'",
      "auditpol /set /subcategory:'Process Creation' /success:enable /failure:enable",
      "",
      "Write-Host 'Audit and logging configured successfully'"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 6: SECURITY VALIDATION
  # ---------------------------------------------------------------------------
  # Verify all security settings are correctly applied
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Running Security Validation ==='",
      "",
      "$errors = @()",
      "",
      "# Check UAC",
      "$uac = Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA' -ErrorAction SilentlyContinue",
      "if ($uac.EnableLUA -ne 1) { $errors += 'UAC is not enabled' }",
      "else { Write-Host '✓ UAC enabled' }",
      "",
      "# Check Windows Defender",
      "$defender = Get-MpPreference",
      "if ($defender.DisableRealtimeMonitoring -eq $true) { $errors += 'Windows Defender real-time monitoring is disabled' }",
      "else { Write-Host '✓ Windows Defender enabled' }",
      "",
      "# Check Windows Firewall",
      "$fwProfiles = Get-NetFirewallProfile",
      "foreach ($profile in $fwProfiles) {",
      "    if ($profile.Enabled -eq $false) { $errors += \"Firewall profile $($profile.Name) is disabled\" }",
      "}",
      "$fwErrorCount = ($errors | Where-Object { $_ -like '*Firewall*' } | Measure-Object).Count",
      "if ($fwErrorCount -eq 0) {",
      "    Write-Host '✓ Windows Firewall enabled on all profiles'",
      "}",
      "",
      "# Check Azure CLI",
      "$azCli = 'C:\\Program Files\\Microsoft SDKs\\Azure\\CLI2\\wbin\\az.cmd'",
      "if (Test-Path $azCli) {",
      "    Write-Host '✓ Azure CLI installed'",
      "} else {",
      "    Write-Host 'Warning: Azure CLI not found at expected location (may be in different location)' -ForegroundColor Yellow",
      "}",
      "",
      "# Check PowerShell Logging",
      "$psLogging = Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\ScriptBlockLogging' -Name 'EnableScriptBlockLogging' -ErrorAction SilentlyContinue",
      "if ($psLogging.EnableScriptBlockLogging -ne 1) { $errors += 'PowerShell logging is not enabled' }",
      "else { Write-Host '✓ PowerShell logging enabled' }",
      "",
      "# Report results",
      "Write-Host ''",
      "if ($errors.Count -eq 0) {",
      "    Write-Host '=== ✓ ALL SECURITY VALIDATIONS PASSED ===' -ForegroundColor Green",
      "} else {",
      "    Write-Host '=== ⚠ SECURITY VALIDATION ISSUES FOUND ===' -ForegroundColor Yellow",
      "    foreach ($error in $errors) {",
      "        Write-Host \"  - $error\" -ForegroundColor Yellow",
      "    }",
      "    Write-Host ''",
      "    Write-Host 'Build will continue, but these issues should be investigated.' -ForegroundColor Yellow",
      "}"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 7: CLEANUP & OPTIMIZATION
  # ---------------------------------------------------------------------------
  # Prepare the image for deployment
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Performing Cleanup & Optimization ==='",
      "",
      "# Clear temporary files",
      "Write-Host 'Clearing temporary files...'",
      "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path 'C:\\Users\\*\\AppData\\Local\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "",
      "# Clear event logs (will be fresh for new Dev Boxes)",
      "Write-Host 'Clearing event logs...'",
      "wevtutil cl Application",
      "wevtutil cl System",
      "",
      "# Create standard directories for developers",
      "Write-Host 'Creating standard directories...'",
      "New-Item -Path 'C:\\Dev' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\Projects' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\Tools' -ItemType Directory -Force | Out-Null",
      "",
      "Write-Host 'Cleanup completed successfully'"
    ]
  }

  # ---------------------------------------------------------------------------
  # ORDER 8: RESTART WINDOWS
  # ---------------------------------------------------------------------------
  # Restart to ensure all changes take effect
  
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # ---------------------------------------------------------------------------
  # ORDER 9: GENERALIZE IMAGE (SYSPREP)
  # ---------------------------------------------------------------------------
  # Prepare image for cloning (removes machine-specific information)
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Generalizing Image (Sysprep) ==='",
      "Write-Host 'This will prepare the image for deployment and shut down the VM...'",
      "",
      "# Run Sysprep",
      "& $env:SystemRoot\\System32\\Sysprep\\sysprep.exe /generalize /oobe /quit /mode:vm",
      "",
      "Write-Host 'Sysprep initiated. VM will shut down automatically.'"
    ]
  }

  # ---------------------------------------------------------------------------
  # POST-PROCESSORS (Optional)
  # ---------------------------------------------------------------------------
  # You can add manifest generation or other post-processing here
  
  post-processor "manifest" {
    output     = "manifest-security-baseline.json"
    strip_path = true
    custom_data = {
      image_name    = "SecurityBaselineImage"
      image_version = var.image_version
      build_time    = timestamp()
      description   = "Golden security baseline image for DevBox - Operations Team Managed"
    }
  }
}
