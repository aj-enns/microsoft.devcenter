variable "gallery_name" {
  description = "The name of Azure Compute Gallery"
  type        = string
}

variable "image_definitions" {
  description = "List of image definitions to create in the gallery"
  type = list(object({
    name      = string
    offer     = string
    publisher = string
    sku       = string
  }))
  default = [
    {
      name      = "CustomizedImage"
      offer     = "windows-ent-cpc"
      publisher = "MicrosoftWindowsDesktop"
      sku       = "win11-22h2-ent-cpc-m365"
    }
  ]
}

variable "image_template_name" {
  description = "The name of image template for customized image"
  type        = string
}

variable "template_identity_name" {
  description = "The name of image template identity"
  type        = string
}

variable "location" {
  description = "Primary location for all resources"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "guid_id" {
  description = "The guid id that generates the different name for image build name"
  type        = string
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

locals {
  # Reference commands that are now implemented in Packer
  customized_commands = [
    {
      type = "PowerShell"
      name = "Install Choco and other tools (now in Packer)"
      inline = [
        "Set-ExecutionPolicy Bypass -Scope Process -Force",
        "Install Chocolatey, Git, Azure CLI, VS Code, etc.",
        "Configure VS Code extensions including GitHub Copilot",
        "See packer/windows-devbox.pkr.hcl for full implementation"
      ]
    }
  ]
}

# Compute Gallery
resource "azurerm_shared_image_gallery" "main" {
  name                = var.gallery_name
  resource_group_name = var.resource_group_name
  location            = var.location
}

# Image Definitions (multiple)
resource "azurerm_shared_image" "main" {
  for_each            = { for img in var.image_definitions : img.name => img }
  
  name                = each.value.name
  gallery_name        = azurerm_shared_image_gallery.main.name
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows"
  hyper_v_generation  = "V2"
  architecture        = "x64"
  trusted_launch_enabled = true

  identifier {
    offer     = each.value.offer
    publisher = each.value.publisher
    sku       = each.value.sku
  }
}

# Note: Template identity and role assignments removed since we're using Packer
# Packer will use your Azure authentication (az login or service principal)
# to build and publish images to the gallery

# Note: Image creation is now handled by Packer
# Run the Packer build from the packer/ directory to create the customized image
# The Packer configuration will build the image and store it in this gallery
#
# To build the image:
# 1. cd packer/
# 2. Copy variables.pkrvars.hcl.example to variables.pkrvars.hcl and customize
# 3. Run: .\build-image.ps1 -Action all
#
# The Packer build includes:
# ${join("\n# ", [for cmd in local.customized_commands : "${cmd.name}: ${join(", ", cmd.inline)}"])}

# The gallery and image definition are created by Terraform
# Packer will create image versions in this gallery

output "gallery_name" {
  description = "The name of the compute gallery"
  value       = azurerm_shared_image_gallery.main.name
}

output "gallery_id" {
  description = "The ID of the compute gallery"
  value       = azurerm_shared_image_gallery.main.id
}

output "image_definitions" {
  description = "Map of created image definitions"
  value       = { for k, v in azurerm_shared_image.main : k => v.name }
}

output "template_identity_id" {
  description = "Not used with Packer - Packer uses your Azure authentication"
  value       = null
}

output "image_template_name" {
  description = "The name of the image template"
  value       = var.image_template_name
}