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

# Note: Using Azure CLI authentication - no client credentials needed

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

  # Install Chocolatey (without refreshenv)
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

  # Install development tools via Chocolatey
  provisioner "powershell" {
    inline = [
      "Write-Output 'Installing development tools...'",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
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
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
      "$vscode_extension_dir = 'C:/temp/extensions'",
      "New-Item $vscode_extension_dir -ItemType Directory -Force",
      "[Environment]::SetEnvironmentVariable('VSCODE_EXTENSIONS', $vscode_extension_dir, 'Machine')",
      "$env:VSCODE_EXTENSIONS = $vscode_extension_dir",
      "",
      "# Function to install extension with error handling",
      "$installExtension = {",
      "  param($extensionId)",
      "  try {",
      "    Write-Output \"Installing extension: $extensionId\"",
      "    & 'C:/Program Files/Microsoft VS Code/bin/code.cmd' --install-extension $extensionId --force 2>&1 | Out-Null",
      "    Write-Output \"Successfully installed: $extensionId\"",
      "  } catch {",
      "    Write-Output \"Warning: Failed to install $extensionId - $($_.Exception.Message)\"",
      "  }",
      "}",
      "",
      "# Install essential extensions",
      "& $installExtension 'github.copilot'",
      "& $installExtension 'ms-vscode.azure-account'",
      "& $installExtension 'ms-azuretools.vscode-azureresourcegroups'",
      "& $installExtension 'ms-python.python'",
      "& $installExtension 'ms-dotnettools.csharp'",
      "& $installExtension 'hashicorp.terraform'",
      "",
      "Write-Output 'VS Code extension installation complete'"
    ]
    pause_before = "30s" # Wait for VS Code installation to complete
    valid_exit_codes = [0, 1, 3010]
  }

  # Configure Git globally
  provisioner "powershell" {
    inline = [
      "Write-Output 'Configuring Git...'",
      "$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')",
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
      "Add-MpPreference -ExclusionPath 'C:\\dev' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\repos' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\workspace' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionPath 'C:\\temp' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionProcess 'node.exe' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionProcess 'dotnet.exe' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionProcess 'python.exe' -ErrorAction SilentlyContinue",
      "Add-MpPreference -ExclusionProcess 'git.exe' -ErrorAction SilentlyContinue"
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
      "Install-Module -Name Az -Force -AllowClobber -Scope AllUsers",
      "Install-Module -Name Microsoft.Graph -Force -AllowClobber -Scope AllUsers",
      "Install-Module -Name posh-git -Force -Scope AllUsers"
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

  # # TEMPORARILY COMMENTED OUT FOR DEBUGGING - Windows Update has access denied issues
  # # Run Windows Update (optional, using PowerShell instead of windows-update plugin)
  # provisioner "powershell" {
  #   inline = [
  #     "Write-Output 'Installing Windows Updates...'",
  #     "Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers",
  #     "Import-Module PSWindowsUpdate",
  #     "Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -Verbose",
  #     "Write-Output 'Windows Updates installation completed.'"
  #   ]
  #   valid_exit_codes = [0, 3010] # 3010 = reboot required
  # }

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
      "Write-Output 'System preparation complete.'",
      "Write-Output 'Next step is a REBOOT....'"
    ]
  }

  # Restart Windows to complete installations
  provisioner "windows-restart" {
    restart_timeout = "15m"
  }

  # Generalize the image (this runs sysprep)
  provisioner "powershell" {
    inline = [
      "Write-Output 'Running sysprep to generalize the image...'",
      "Write-Output 'Sysprep will shutdown the VM automatically'",
      "& $env:SystemRoot\\System32\\Sysprep\\sysprep.exe /generalize /oobe /quit"
    ]
  }
}