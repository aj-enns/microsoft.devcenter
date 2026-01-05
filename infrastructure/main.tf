# DevCenter Infrastructure - Operations Team Managed
# This configuration creates the core infrastructure for DevCenter
# Separates infrastructure concerns from image customization

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Create resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Environment = "DevCenter"
    Purpose     = "DevBox-Multi-Images-Roles"
    CreatedBy   = "Terraform"
    ManagedBy   = "Operations-Team"
  }
}

# Random string for unique resource naming
resource "random_string" "resource_token" {
  length  = 13
  special = false
  upper   = false
}

# Local values for resource naming
locals {
  abbreviations = {
    network_virtual_networks                  = "vnet-"
    network_virtual_networks_subnets         = "snet-"
    network_connections                       = "con-"
    devcenter                                = "dc-"
    devcenter_project                        = "dcprj-"
    devcenter_networking_resource_group      = "ni-"
    keyvault                                 = "kv-"
    compute_galleries                        = "gal"
    managed_identity_user_assigned_identities = "id-"
  }
  
  resource_token = random_string.resource_token.result
  
  nc_name = var.network_connection_name != "" ? var.network_connection_name : "${local.abbreviations.network_connections}${local.resource_token}"
  id_name = var.user_identity_name != "" ? var.user_identity_name : "${local.abbreviations.managed_identity_user_assigned_identities}${local.resource_token}"
  
  devcenter_name = var.devcenter_name != "" ? var.devcenter_name : "${local.abbreviations.devcenter}${local.resource_token}"
  project_name   = var.project_name != "" ? var.project_name : "${local.abbreviations.devcenter_project}${local.resource_token}"
  
  vnet_name   = var.network_vnet_name != "" ? var.network_vnet_name : "${local.abbreviations.network_virtual_networks}${local.resource_token}"
  subnet_name = var.network_subnet_name != "" ? var.network_subnet_name : "${local.abbreviations.network_virtual_networks_subnets}${local.resource_token}"
  
  gallery_name = var.gallery_name != "" ? var.gallery_name : "${local.abbreviations.compute_galleries}${local.resource_token}"
}

# Virtual Network Module
module "vnet" {
  count  = var.existing_subnet_id == "" ? 1 : 0
  source = "./modules/vnet"
  
  resource_group_name       = azurerm_resource_group.main.name
  vnet_name                 = local.vnet_name
  subnet_name               = local.subnet_name
  location                  = var.location
  vnet_address_prefixes     = var.network_vnet_address_prefixes
  subnet_address_prefixes   = var.network_subnet_address_prefixes
  enable_nat_gateway        = var.enable_nat_gateway
}

# User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "main" {
  name                = local.id_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

# Azure Compute Gallery
resource "azurerm_shared_image_gallery" "main" {
  name                = local.gallery_name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  description         = "DevCenter custom images gallery"

  tags = {
    Environment = "DevCenter"
    ManagedBy   = "Operations-Team"
  }
}

# Security Baseline Image Definition
# This MUST exist before Packer can publish image versions to it
resource "azurerm_shared_image" "security_baseline" {
  name                = "SecurityBaselineImage"
  gallery_name        = azurerm_shared_image_gallery.main.name
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  os_type             = "Windows"
  hyper_v_generation  = "V2"

  identifier {
    publisher = "DevBoxOperations"
    offer     = "SecurityBaseline"
    sku       = "win11-ent-cpc-m365"
  }

  tags = {
    Environment = "DevCenter"
    ManagedBy   = "Operations-Team"
    Purpose     = "Security baseline for all DevBox images"
  }
}

# DevCenter Module
module "devcenter" {
  source = "./modules/devcenter"
  
  location                        = var.location
  resource_group_name            = azurerm_resource_group.main.name
  devcenter_name                 = local.devcenter_name
  subnet_id                      = var.existing_subnet_id != "" ? var.existing_subnet_id : module.vnet[0].subnet_id
  network_connection_name        = local.nc_name
  project_name                   = local.project_name
  networking_resource_group_name = "${local.abbreviations.devcenter_networking_resource_group}${local.nc_name}-${var.location}"
  principal_id                   = var.user_principal_id
  principal_type                 = var.user_principal_type
  managed_identity_id            = azurerm_user_assigned_identity.main.id
  managed_identity_principal_id  = azurerm_user_assigned_identity.main.principal_id
  gallery_id                     = azurerm_shared_image_gallery.main.id
}
