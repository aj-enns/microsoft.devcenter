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
      name      = "VisualStudioImage"
      offer     = "windows-ent-cpc"
      publisher = "MicrosoftWindowsDesktop"
      sku       = "win11-22h2-ent-cpc-m365"
    }
  ]
}

variable "location" {
  description = "Primary location for all resources"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

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

# Note: Image versions are created by Packer, not Terraform
# This module creates the gallery infrastructure (gallery + image definitions)
# Packer builds and publishes actual image versions to these definitions
#
# To build images:
#   cd packer
#   .\build-image.ps1 -ImageType visualstudio -Action all
#   .\build-image.ps1 -ImageType intellij -Action all

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