# =============================================================================
# VS CODE TEAM DEVBOX IMAGE
# =============================================================================
# Managed by: VS Code Development Team
# Purpose: Custom image with VS Code and related development tools
#
# IMPORTANT: This template MUST use SecurityBaselineImage as the source.
# The baseline image contains mandatory security configurations that cannot
# be bypassed. This template adds VS Code-specific customizations on top.
#
# Protected by: CI/CD validation ensures SecurityBaselineImage is used
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
  description = "Azure subscription ID"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name where the image will be stored"
}

variable "gallery_name" {
  type        = string
  description = "Name of the Azure Compute Gallery"
}

variable "baseline_image_version" {
  type        = string
  description = "Version of SecurityBaselineImage to build from (e.g., 1.0.0)"
  default     = "1.0.0"
}

variable "image_version" {
  type        = string
  description = "Version of this team image (format: x.x.x)"
  default     = "1.0.0"
}

variable "location" {
  type        = string
  description = "Azure location"
  default     = "eastus"
}

variable "vm_size" {
  type        = string
  description = "Size of the build VM"
  default     = "Standard_D2s_v3"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  image_name = "VSCodeDevImage"
}

# =============================================================================
# SOURCE CONFIGURATION
# =============================================================================
# CRITICAL: Uses SecurityBaselineImage from the gallery (Operations-controlled)
# This ensures all mandatory security configurations are present

source "azure-arm" "vscode_customization" {
  # Authentication
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id

  # Build Configuration
  # Publish directly to gallery (required for TrustedLaunch/SecureBoot support)
  location                 = var.location
  vm_size                  = var.vm_size
  build_resource_group_name = var.resource_group_name  # Build VM in same RG as gallery

  # =========================================================================
  # SOURCE IMAGE: SecurityBaselineImage (REQUIRED - DO NOT CHANGE)
  # =========================================================================
  # This image contains mandatory security configurations managed by the
  # Operations Team. Attempting to use any other source will fail CI/CD.
  
  shared_image_gallery {
    subscription   = var.subscription_id
    resource_group = var.resource_group_name
    gallery_name   = var.gallery_name
    image_name     = "SecurityBaselineImage"
    image_version  = var.baseline_image_version
  }

  # Destination: VS Code Team Image (direct to gallery)
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.resource_group_name
    gallery_name         = var.gallery_name
    image_name           = local.image_name
    image_version        = var.image_version
    replication_regions  = [var.location]
    storage_account_type = "Standard_LRS"
  }

  # OS Configuration
  os_type = "Windows"

  # Security Configuration - REQUIRED for TrustedLaunch source images
  security_type       = "TrustedLaunch"
  secure_boot_enabled = true
  vtpm_enabled        = true

  # Communicator Settings
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "15m"
  winrm_username = "packer"

  # Tags
  azure_tags = {
    Created_by    = "Packer"
    Team          = "VSCode-Team"
    Purpose       = "DevCenter_VSCode_Image"
    BaselineImage = "SecurityBaselineImage-${var.baseline_image_version}"
    Timestamp     = local.timestamp
  }

  # Cleanup
  async_resourcegroup_delete = true
}

# =============================================================================
# BUILD PROCESS
# =============================================================================

build {
  name    = "vscode-team-image"
  sources = ["source.azure-arm.vscode_customization"]

  # ---------------------------------------------------------------------------
  # INITIAL SETUP
  # ---------------------------------------------------------------------------
  # The baseline image already has Chocolatey, Azure CLI, and all security
  # configurations. We only add VS Code-specific tools here.
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== VS Code Team Customization Build ==='",
      "Write-Host 'Base Image: SecurityBaselineImage v${var.baseline_image_version}'",
      "Write-Host 'Target Version: ${var.image_version}'",
      "Write-Host ''",
      "Write-Host 'Waiting for system to stabilize...'",
      "Start-Sleep -Seconds 30",
      "",
      "# Refresh environment",
      "$env:ChocolateyInstall = 'C:\\ProgramData\\chocolatey'",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')"
    ]
  }

  # ---------------------------------------------------------------------------
  # VS CODE TEAM CUSTOMIZATIONS
  # ---------------------------------------------------------------------------
  # All customizations below are team-specific. The baseline security
  # configurations are already applied and cannot be modified.
  
  # Install core development tools
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing VS Code Development Tools ==='",
      "",
      "# Refresh environment to use Chocolatey from baseline image",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "Write-Host 'Installing Git...'",
      "choco install -y git --params '/GitAndUnixToolsOnPath /NoAutoCrlf' --limit-output",
      "",
      "Write-Host 'Installing Visual Studio Code...'",
      "choco install -y vscode --limit-output",
      "",
      "Write-Host 'Installing Node.js...'",
      "choco install -y nodejs --limit-output",
      "",
      "Write-Host 'Installing Python...'",
      "choco install -y python --limit-output",
      "",
      "Write-Host 'Installing .NET SDK...'",
      "choco install -y dotnet-sdk --limit-output",
      "",
      "Write-Host 'Installing Docker Desktop...'",
      "choco install -y docker-desktop --limit-output",
      "",
      "Write-Host 'Installing Terraform...'",
      "choco install -y terraform --limit-output",
      "",
      "Write-Host '✓ Core tools installation complete'"
    ]
    valid_exit_codes = [0, 3010]
  }

  # Configure VS Code extensions
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Installing VS Code Extensions ==='",
      "",
      "# Refresh PATH",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "$extensions = @(",
      "  'github.copilot',",
      "  'ms-vscode.azure-account',",
      "  'ms-azuretools.vscode-azureresourcegroups',",
      "  'ms-python.python',",
      "  'ms-dotnettools.csharp',",
      "  'hashicorp.terraform',",
      "  'ms-vscode-remote.remote-containers',",
      "  'esbenp.prettier-vscode',",
      "  'dbaeumer.vscode-eslint'",
      ")",
      "",
      "foreach ($ext in $extensions) {",
      "  try {",
      "    Write-Host \"Installing extension: $ext\"",
      "    & 'C:\\Program Files\\Microsoft VS Code\\bin\\code.cmd' --install-extension $ext --force 2>&1 | Out-Null",
      "  } catch {",
      "    Write-Host \"Warning: Failed to install $ext\" -ForegroundColor Yellow",
      "  }",
      "}",
      "",
      "Write-Host '✓ VS Code extensions installed'"
    ]
    pause_before = "30s"
    valid_exit_codes = [0, 1, 3010]
  }

  # Configure Git
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Git ==='",
      "",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "",
      "git config --system core.autocrlf false",
      "git config --system core.longpaths true",
      "git config --system credential.helper manager-core",
      "",
      "Write-Host '✓ Git configuration complete'"
    ]
  }

  # ---------------------------------------------------------------------------
  # TEAM-SPECIFIC CONFIGURATIONS
  # ---------------------------------------------------------------------------
  
  # Configure Windows Defender exclusions for dev folders
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Configuring Performance Optimizations ==='",
      "",
      "# Add Defender exclusions for common dev folders (improves performance)",
      "Add-MpPreference -ExclusionPath 'C:\\Dev' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\Projects' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\workspace' -ErrorAction SilentlyContinue",
      "",
      "Write-Host '✓ Performance optimizations configured'"
    ]
  }

  # Create additional dev directories
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Creating Team Directories ==='",
      "",
      "New-Item -Path 'C:\\workspace' -ItemType Directory -Force | Out-Null",
      "New-Item -Path 'C:\\repos' -ItemType Directory -Force | Out-Null",
      "",
      "Write-Host '✓ Team directories created'"
    ]
  }

  # ---------------------------------------------------------------------------
  # SECURITY VALIDATION
  # ---------------------------------------------------------------------------
  # Verify baseline security configurations are still intact
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Verifying Security Baseline ==='",
      "",
      "$errors = @()",
      "",
      "# Check UAC (from baseline image)",
      "$uac = Get-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System' -Name 'EnableLUA' -ErrorAction SilentlyContinue",
      "if ($uac.EnableLUA -ne 1) { $errors += 'UAC is not enabled' }",
      "else { Write-Host '✓ UAC enabled' }",
      "",
      "# Check Windows Defender (from baseline image)",
      "$defender = Get-MpPreference",
      "if ($defender.DisableRealtimeMonitoring -eq $true) { $errors += 'Windows Defender disabled' }",
      "else { Write-Host '✓ Windows Defender enabled' }",
      "",
      "# Check Firewall (from baseline image)",
      "$fwProfiles = Get-NetFirewallProfile",
      "$fwDisabled = $fwProfiles | Where-Object { $_.Enabled -eq $false }",
      "if ($fwDisabled.Count -gt 0) { $errors += 'Windows Firewall is disabled on some profiles' }",
      "else { Write-Host '✓ Windows Firewall enabled' }",
      "",
      "# Check Azure CLI (from baseline image)",
      "try {",
      "    $null = az --version 2>&1",
      "    Write-Host '✓ Azure CLI available'",
      "} catch {",
      "    $errors += 'Azure CLI is not available'",
      "}",
      "",
      "Write-Host ''",
      "if ($errors.Count -eq 0) {",
      "    Write-Host '=== ✓ SECURITY VALIDATION PASSED ===' -ForegroundColor Green",
      "    Write-Host 'All baseline security configurations are intact' -ForegroundColor Green",
      "} else {",
      "    Write-Host '=== ⚠ SECURITY VALIDATION FAILED ===' -ForegroundColor Red",
      "    foreach ($error in $errors) {",
      "        Write-Host \"  ✗ $error\" -ForegroundColor Red",
      "    }",
      "    throw 'Security validation failed. Baseline configurations were compromised.'",
      "}"
    ]
  }

  # ---------------------------------------------------------------------------
  # CLEANUP & FINALIZATION
  # ---------------------------------------------------------------------------
  
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Cleanup & Optimization ==='",
      "",
      "# Clear temporary files",
      "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path 'C:\\Users\\*\\AppData\\Local\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "",
      "# Clear Recycle Bin",
      "Clear-RecycleBin -Force -ErrorAction SilentlyContinue",
      "",
      "Write-Host '✓ Cleanup complete'"
    ]
  }

  # Restart Windows
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Generalize image (Sysprep)
  provisioner "powershell" {
    inline = [
      "Write-Host '=== Generalizing Image (Sysprep) ==='",
      "Write-Host 'Preparing image for deployment...'",
      "",
      "& $env:SystemRoot\\System32\\Sysprep\\sysprep.exe /generalize /oobe /quit /mode:vm",
      "",
      "Write-Host 'Sysprep initiated. VM will shut down automatically.'"
    ]
  }

  # Generate manifest
  post-processor "manifest" {
    output     = "manifest-vscode-devbox.json"
    strip_path = true
    custom_data = {
      team_name           = "VS Code Team"
      image_name          = local.image_name
      image_version       = var.image_version
      baseline_image      = "SecurityBaselineImage"
      baseline_version    = var.baseline_image_version
      build_time          = timestamp()
      description         = "VS Code development image with Node.js, Python, .NET, Docker, and Terraform"
    }
  }
}
