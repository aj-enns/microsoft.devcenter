# Base Windows Image Configuration
# Managed by Operations Team
# This file contains shared base configuration for all Windows DevBox images

# Common Packer Variables
# These should be overridden in team-specific variable files

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
  default     = env("ARM_SUBSCRIPTION_ID")
}

variable "tenant_id" {
  type        = string
  description = "Azure tenant ID"
  default     = env("ARM_TENANT_ID")
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name where the image will be stored"
}

variable "gallery_name" {
  type        = string
  description = "Name of the Azure Compute Gallery"
}

variable "image_definition_name" {
  type        = string
  description = "Name of the image definition"
}

variable "image_version" {
  type        = string
  description = "Version of the image (format: x.x.x)"
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

variable "image_publisher" {
  type        = string
  description = "Base image publisher"
  default     = "MicrosoftWindowsDesktop"
}

variable "image_offer" {
  type        = string
  description = "Base image offer"
  default     = "windows-ent-cpc"
}

variable "image_sku" {
  type        = string
  description = "Base image SKU"
  default     = "win11-24h2-ent-cpc-m365"
}

# Local values
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# Shared Source Configuration Template
# Teams will reference this in their own configurations
source "azure-arm" "windows_base" {
  # Authentication - Use Azure CLI
  use_azure_cli_auth = true
  subscription_id    = var.subscription_id
  tenant_id         = var.tenant_id

  # Resource configuration
  managed_image_resource_group_name = var.resource_group_name
  managed_image_name               = "packer-${var.image_definition_name}-${local.timestamp}"

  # Shared Image Gallery configuration
  shared_image_gallery_destination {
    subscription         = var.subscription_id
    resource_group       = var.resource_group_name
    gallery_name         = var.gallery_name
    image_name          = var.image_definition_name
    image_version       = var.image_version
    replication_regions = [var.location]
    storage_account_type = "Standard_LRS"
  }

  # Build VM configuration
  os_type         = "Windows"
  image_publisher = var.image_publisher
  image_offer     = var.image_offer
  image_sku       = var.image_sku
  location        = var.location
  vm_size         = var.vm_size

  # Communicator configuration
  communicator   = "winrm"
  winrm_use_ssl  = true
  winrm_insecure = true
  winrm_timeout  = "5m"
  winrm_username = "packer"

  # Azure-specific settings
  azure_tags = {
    Created_by = "Packer"
    Purpose    = "DevCenter_CustomImage"
    Timestamp  = local.timestamp
    ManagedBy  = "Operations-Team"
  }
}

# Common Provisioners
# These are standard steps that all images should include

# Wait for system to be ready
build {
  name = "common-setup"
  
  provisioner "powershell" {
    inline = [
      "Write-Output 'Waiting for system to be ready...'",
      "Start-Sleep -Seconds 30"
    ]
  }

  # Install Chocolatey (package manager)
  provisioner "powershell" {
    inline = [
      "Write-Output 'Installing Chocolatey...'",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))",
      "",
      "# Manually refresh environment for this session",
      "$env:ChocolateyInstall = 'C:\\ProgramData\\chocolatey'",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "Write-Output 'Chocolatey installation complete'"
    ]
  }
}

# Common cleanup steps (to be run at the end of all builds)
build {
  name = "common-cleanup"
  
  # Configure Windows Defender exclusions for development
  provisioner "powershell" {
    inline = [
      "Write-Output 'Configuring Windows Defender exclusions for development...'",
      "Add-MpPreference -ExclusionPath 'C:\\dev' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\repos' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\workspace' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\temp' -ErrorAction SilentlyContinue"
    ]
  }

  # Create standard development directories
  provisioner "powershell" {
    inline = [
      "Write-Output 'Creating development directories...'",
      "New-Item -Path 'C:\\dev' -ItemType Directory -Force",
      "New-Item -Path 'C:\\repos' -ItemType Directory -Force",
      "New-Item -Path 'C:\\workspace' -ItemType Directory -Force"
    ]
  }

  # Clean up temporary files
  provisioner "powershell" {
    inline = [
      "Write-Output 'Cleaning up temporary files...'",
      "Remove-Item -Path 'C:\\Windows\\Temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Remove-Item -Path 'C:\\temp\\*' -Recurse -Force -ErrorAction SilentlyContinue",
      "Clear-RecycleBin -Force -ErrorAction SilentlyContinue"
    ]
  }

  # Final system preparation
  provisioner "powershell" {
    inline = [
      "Write-Output 'Preparing system for imaging...'",
      "# Remove any temporary user profiles",
      "Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false -and $_.LocalPath -like '*temp*' } | Remove-WmiObject -ErrorAction SilentlyContinue",
      "",
      "# Clear event logs",
      "wevtutil el | Foreach-Object {wevtutil cl $_ 2>$null}",
      "",
      "Write-Output 'System preparation complete.'"
    ]
  }

  # Restart Windows to complete installations
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Generalize the image (sysprep)
  provisioner "powershell" {
    inline = [
      "Write-Output 'Running sysprep to generalize the image...'",
      "Write-Output 'Sysprep will shutdown the VM automatically'",
      "& $env:SystemRoot\\System32\\Sysprep\\sysprep.exe /generalize /oobe /quit"
    ]
  }
}
