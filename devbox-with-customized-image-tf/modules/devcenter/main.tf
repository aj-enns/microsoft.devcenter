variable "devcenter_name" {
  description = "The name of Dev Center e.g. dc-devbox-test"
  type        = string
}

variable "network_connection_name" {
  description = "The name of Network Connection e.g. con-devbox-test"
  type        = string
}

variable "networking_resource_group_name" {
  description = "The name of Resource Group hosting network connection e.g. rg-con-devbox-test-eastus"
  type        = string
}

variable "subnet_id" {
  description = "The subnet id hosting Dev Box"
  type        = string
}

variable "project_name" {
  description = "The name of Dev Center project e.g. dcprj-devbox-test"
  type        = string
}

variable "principal_id" {
  description = "The user or group id that will be granted to Devcenter Dev Box User and Deployment Environments User role"
  type        = string
}

variable "location" {
  description = "Primary location for all resources e.g. eastus"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "gallery_name" {
  description = "The name of Azure Compute Gallery"
  type        = string
}

variable "image_definition_name" {
  description = "The name of Azure Compute Gallery image definition"
  type        = string
}

variable "image_template_name" {
  description = "The name of image template for customized image"
  type        = string
}

variable "principal_type" {
  description = "The type of principal id: User or Group"
  type        = string
  default     = "User"
}

variable "template_identity_id" {
  description = "The id of template identity user can read the image template status"
  type        = string
}

variable "guid_id" {
  description = "The guid id that generates the different name for image template. Please keep it by default"
  type        = string
}

variable "managed_identity_id" {
  description = "The ID of the managed identity"
  type        = string
}

variable "managed_identity_principal_id" {
  description = "The principal ID of the managed identity"
  type        = string
}

variable "devcenter_settings" {
  description = "DevCenter settings from JSON file"
  type = object({
    customizedImageDevboxdefinitions = list(object({
      name      = string
      compute   = string
      storage   = string
      imageType = optional(string, "CustomizedImage")
    }))
    customizedImagePools = list(object({
      name          = string
      definition    = string
      administrator = string
    }))
  })
}

# Data sources
data "azurerm_shared_image_gallery" "main" {
  name                = var.gallery_name
  resource_group_name = var.resource_group_name
}

data "azurerm_client_config" "current" {}

# Local values
locals {
  # DevCenter Dev Box User role
  devcenter_devbox_user_role = "45d50f46-0b78-4001-a660-4198cbe8cd05"
  contributor_role          = "b24988ac-6180-42a0-ab88-20f7382dd24c"
  reader_role              = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
  # Used when Dev Center associate with Azure Compute Gallery
  windows365_principal_id = "8eec7c09-06ae-48e9-aafd-9fb31a5d5175"
  
  # Map image types to their actual image references
  image_references = {
    "CustomizedImage"   = "${azurerm_dev_center.main.id}/galleries/${var.gallery_name}/images/CustomizedImage"
    "IntelliJDevImage" = "${azurerm_dev_center.main.id}/galleries/${var.gallery_name}/images/IntelliJDevImage"
    # Default to built-in VS2022 if no image type specified
    "default"          = "${azurerm_dev_center.main.id}/galleries/default/images/microsoftvisualstudio_visualstudioplustools_vs-2022-ent-general-win11-m365-gen2"
  }
  
  query_template_progress     = substr("${var.image_definition_name}-${var.guid_id}-query", 0, 64)
  
  compute = {
    "8c-32gb"   = "general_i_8c32gb256ssd_v2"
    "16c-64gb"  = "general_i_8c32gb512ssd_v2"
    "32c-128gb" = "general_i_8c32gb1024ssd_v2"
  }
}

# DevCenter
resource "azurerm_dev_center" "main" {
  name                = var.devcenter_name
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "UserAssigned"
    identity_ids = [
      var.managed_identity_id
    ]
  }
}

# Gallery Role Assignments
resource "azurerm_role_assignment" "contributor_gallery" {
  scope                = data.azurerm_shared_image_gallery.main.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.contributor_role}"
  principal_id         = var.managed_identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "reader_gallery" {
  scope                = data.azurerm_shared_image_gallery.main.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.reader_role}"
  principal_id         = local.windows365_principal_id
  principal_type       = "ServicePrincipal"
}

# DevCenter Gallery
resource "azurerm_dev_center_gallery" "main" {
  dev_center_id       = azurerm_dev_center.main.id
  shared_gallery_id   = data.azurerm_shared_image_gallery.main.id
  name               = var.gallery_name

  depends_on = [
    azurerm_role_assignment.reader_gallery,
    azurerm_role_assignment.contributor_gallery
  ]
}

# Network Connection
resource "azurerm_dev_center_network_connection" "main" {
  name                = var.network_connection_name
  resource_group_name = var.resource_group_name
  location            = var.location
  domain_join_type    = "AzureADJoin"
  subnet_id           = var.subnet_id
}

# Note: DevCenter attached networks and some other DevCenter resources 
# may not be fully supported in the current Terraform AzureRM provider
# You may need to use the azapi provider or create these manually

# Placeholder for attached network - replace with actual resource when available
resource "null_resource" "attached_network_placeholder" {
  triggers = {
    dev_center_id         = azurerm_dev_center.main.id
    network_connection_id = azurerm_dev_center_network_connection.main.id
  }
}

# Dev Box Definitions - supports multiple image types
resource "azurerm_dev_center_dev_box_definition" "main" {
  for_each = { for def in var.devcenter_settings.customizedImageDevboxdefinitions : def.name => def }
  
  name               = each.value.name
  dev_center_id      = azurerm_dev_center.main.id
  location           = var.location
  
  # Use custom image if imageType is specified and available, otherwise built-in VS2022
  image_reference_id = can(local.image_references[each.value.imageType]) ? local.image_references[each.value.imageType] : local.image_references["default"]
  sku_name          = local.compute[each.value.compute]

  depends_on = [
    null_resource.attached_network_placeholder,
    azurerm_dev_center_gallery.main
  ]
}

# Project
resource "azurerm_dev_center_project" "main" {
  name               = var.project_name
  resource_group_name = var.resource_group_name
  location           = var.location
  dev_center_id      = azurerm_dev_center.main.id
}

# Note: DevCenter project pools may not be fully supported in current Terraform provider
# These would need to be created manually or using azapi provider
resource "null_resource" "project_pools" {
  count = length(var.devcenter_settings.customizedImagePools)
  
  triggers = {
    name                = var.devcenter_settings.customizedImagePools[count.index].name
    project_id          = azurerm_dev_center_project.main.id
    definition_name     = var.devcenter_settings.customizedImagePools[count.index].definition
    administrator       = var.devcenter_settings.customizedImagePools[count.index].administrator
  }

  depends_on = [
    azurerm_dev_center_dev_box_definition.main
  ]
}

# DevBox Role Assignment
resource "azurerm_role_assignment" "devbox" {
  count                = var.principal_id != "" ? 1 : 0
  scope                = azurerm_dev_center_project.main.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/${local.devcenter_devbox_user_role}"
  principal_id         = var.principal_id
  principal_type       = var.principal_type
}

# Outputs
output "devcenter_name" {
  description = "The name of the DevCenter"
  value       = azurerm_dev_center.main.name
}

output "customized_image_devbox_definitions" {
  description = "The names of the customized image DevBox definitions"
  value       = join(", ", [for def in azurerm_dev_center_dev_box_definition.main : def.name])
}

output "network_connection_name" {
  description = "The name of the network connection"
  value       = azurerm_dev_center_network_connection.main.name
}

output "project_name" {
  description = "The name of the project"
  value       = azurerm_dev_center_project.main.name
}

output "customized_image_pools" {
  description = "The list of customized image pools"
  value = [
    for i, pool in var.devcenter_settings.customizedImagePools : {
      name = pool.name
    }
  ]
}