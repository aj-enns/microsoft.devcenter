# Packer configuration for building customized Windows image for DevCenter

packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 2"
    }
  }
}

# Variables
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

variable "client_id" {
  type        = string
  description = "Azure client ID"
  default     = env("ARM_CLIENT_ID")
}

variable "client_secret" {
  type        = string
  description = "Azure client secret"
  default     = env("ARM_CLIENT_SECRET")
  sensitive   = true
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
  default     = "CustomizedImage"
}

variable "image_version" {
  type        = string
  description = "Version of the image (format: x.x.x)"
  default     = "1.0.0"
}

variable "location" {
  type        = string
  description = "Azure location"
  default     = "East US"
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
  default     = "win11-22h2-ent-cpc-m365"
}

# Local values
locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# Source configuration
source "azure-arm" "windows_devbox" {
  # Authentication
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
  client_secret   = var.client_secret

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
  }
}

# Build configuration
build {
  name = "windows-devbox-image"
  sources = [
    "source.azure-arm.windows_devbox"
  ]

  # Wait for system to be ready
  provisioner "powershell" {
    inline = [
      "Write-Output 'Waiting for system to be ready...'",
      "Start-Sleep -Seconds 30"
    ]
  }

  # Install Chocolatey
  provisioner "powershell" {
    inline = [
      "Write-Output 'Installing Chocolatey...'",
      "Set-ExecutionPolicy Bypass -Scope Process -Force",
      "[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072",
      "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))",
      "refreshenv"
    ]
  }

  # Install development tools via Chocolatey
  provisioner "powershell" {
    inline = [
      "Write-Output 'Installing development tools...'",
      "choco install -y git --params '/GitAndUnixToolsOnPath /NoAutoCrlf'",
      "choco install -y azure-cli",
      "choco install -y vscode",
      "choco install -y nodejs",
      "choco install -y python",
      "choco install -y dotnet-sdk",
      "choco install -y docker-desktop",
      "choco install -y terraform",
      "choco install -y kubernetes-cli"
    ]
    valid_exit_codes = [0, 3010] # 3010 = reboot required
  }

  # Configure VS Code extensions
  provisioner "powershell" {
    inline = [
      "Write-Output 'Installing VS Code extensions...'",
      "$vscode_extension_dir = 'C:/temp/extensions'",
      "New-Item $vscode_extension_dir -ItemType Directory -Force",
      "[Environment]::SetEnvironmentVariable('VSCODE_EXTENSIONS', $vscode_extension_dir, 'Machine')",
      "$env:VSCODE_EXTENSIONS = $vscode_extension_dir",
      "",
      "# Install essential extensions",
      "& 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension github.copilot --force",
      "& 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension ms-vscode.azure-account --force",
      "& 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension ms-azuretools.vscode-azureresourcegroups --force",
      "& 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension ms-python.python --force",
      "& 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension ms-dotnettools.csharp --force",
      "& 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension hashicorp.terraform --force"
    ]
    pause_before = "30s" # Wait for VS Code installation to complete
  }

  # Configure Git globally
  provisioner "powershell" {
    inline = [
      "Write-Output 'Configuring Git...'",
      "git config --system core.autocrlf false",
      "git config --system core.longpaths true",
      "git config --system credential.helper manager-core"
    ]
  }

  # Install Windows features that might be useful for development
  provisioner "powershell" {
    inline = [
      "Write-Output 'Installing Windows optional features...'",
      "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart",
      "Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart",
      "Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart"
    ]
    valid_exit_codes = [0, 3010] # 3010 = reboot required
  }

  # Configure Windows Defender exclusions for development
  provisioner "powershell" {
    inline = [
      "Write-Output 'Configuring Windows Defender exclusions...'",
      "Add-MpPreference -ExclusionPath 'C:\\dev'",
      "Add-MpPreference -ExclusionPath 'C:\\repos'",
      "Add-MpPreference -ExclusionPath 'C:\\workspace'",
      "Add-MpPreference -ExclusionPath 'C:\\temp'",
      "Add-MpPreference -ExclusionProcess 'node.exe'",
      "Add-MpPreference -ExclusionProcess 'dotnet.exe'",
      "Add-MpPreference -ExclusionProcess 'python.exe'",
      "Add-MpPreference -ExclusionProcess 'git.exe'"
    ]
  }

  # Create development directories
  provisioner "powershell" {
    inline = [
      "Write-Output 'Creating development directories...'",
      "New-Item -Path 'C:\\dev' -ItemType Directory -Force",
      "New-Item -Path 'C:\\repos' -ItemType Directory -Force",
      "New-Item -Path 'C:\\workspace' -ItemType Directory -Force"
    ]
  }

  # Install PowerShell modules useful for Azure development
  provisioner "powershell" {
    inline = [
      "Write-Output 'Installing PowerShell modules...'",
      "Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force",
      "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted",
      "Install-Module -Name Az -Force -AllowClobber",
      "Install-Module -Name Microsoft.Graph -Force -AllowClobber",
      "Install-Module -Name posh-git -Force"
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

  # Run Windows Update (optional, can be commented out to speed up builds)
  provisioner "windows-update" {
    search_criteria = "IsInstalled=0"
    filters = [
      "exclude:$_.Title -like '*Preview*'",
      "include:$true"
    ]
  }

  # Final system preparation
  provisioner "powershell" {
    inline = [
      "Write-Output 'Preparing system for imaging...'",
      "# Remove any temporary user profiles",
      "Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false -and $_.LocalPath -like '*temp*' } | Remove-WmiObject",
      "",
      "# Clear event logs",
      "wevtutil el | Foreach-Object {wevtutil cl $_}",
      "",
      "Write-Output 'System preparation complete.'"
    ]
  }

  # Generalize the image (this runs sysprep)
  provisioner "powershell" {
    inline = [
      "Write-Output 'Running sysprep to generalize the image...'",
      "& $env:SystemRoot\\System32\\Sysprep\\sysprep.exe /generalize /oobe /quiet /quit",
      "while($true) { $imageState = Get-ItemProperty HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Setup\\State | Select ImageState; if($imageState.ImageState -ne 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { Write-Output $imageState.ImageState; Start-Sleep -s 10  } else { break } }"
    ]
  }
}