variable "vnet_name" {
  description = "The name of the Virtual Network"
  type        = string
}

variable "subnet_name" {
  description = "The app subnet name of Dev Box"
  type        = string
}

variable "vnet_address_prefixes" {
  description = "The address prefixes of the vnet"
  type        = string
}

variable "subnet_address_prefixes" {
  description = "The subnet address prefixes for Dev Box"
  type        = string
}

variable "location" {
  description = "The location of the resource"
  type        = string
}

# Data source for resource group
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  address_space       = [var.vnet_address_prefixes]
}

resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefixes]
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = azurerm_subnet.main.name
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = azurerm_subnet.main.id
}