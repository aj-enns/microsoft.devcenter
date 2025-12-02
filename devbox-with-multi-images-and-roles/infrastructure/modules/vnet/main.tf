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

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for outbound connectivity (recommended for production)"
  type        = bool
  default     = true
}

resource "azurerm_virtual_network" "main" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_address_prefixes]
}

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "pip-nat-${var.vnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

# NAT Gateway for outbound connectivity
resource "azurerm_nat_gateway" "main" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "nat-${var.vnet_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  zones               = ["1"]
}

# Associate Public IP with NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "main" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.main[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet" "main" {
  name                 = var.subnet_name
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_address_prefixes]
  
  # Enable default outbound access for DevCenter connectivity
  default_outbound_access_enabled = true
}

# Associate NAT Gateway with Subnet
resource "azurerm_subnet_nat_gateway_association" "main" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.main.id
  nat_gateway_id = azurerm_nat_gateway.main[0].id
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
