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

variable "principal_type" {
  description = "The type of principal id: User or Group"
  type        = string
  default     = "User"
}

variable "managed_identity_id" {
  description = "The ID of the managed identity"
  type        = string
}

variable "managed_identity_principal_id" {
  description = "The principal ID of the managed identity"
  type        = string
}



# Data sources
data "azurerm_client_config" "current" {}

# Local values
locals {
  # DevCenter Dev Box User role
  devcenter_devbox_user_role = "45d50f46-0b78-4001-a660-4198cbe8cd05"
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

# Dev Box Definitions - Created via PowerShell script (02-create-definitions.ps1)
# This allows for flexible image management and supports both built-in and custom images

# Project
resource "azurerm_dev_center_project" "main" {
  name               = var.project_name
  resource_group_name = var.resource_group_name
  location           = var.location
  dev_center_id      = azurerm_dev_center.main.id
  
  # Note: max_dev_boxes_per_user not yet supported in Terraform provider
  # Set this manually via: az devcenter admin project update --name <project> --resource-group <rg> --max-dev-boxes-per-user 10
}

# DevCenter project pools - Created via PowerShell script (03-create-pools.ps1)

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

output "network_connection_name" {
  description = "The name of the network connection"
  value       = azurerm_dev_center_network_connection.main.name
}

output "project_name" {
  description = "The name of the project"
  value       = azurerm_dev_center_project.main.name
}