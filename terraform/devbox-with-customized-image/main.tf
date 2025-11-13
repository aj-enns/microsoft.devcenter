# Configure the Azure Provider
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

# Configure the Microsoft Azure Provider
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
    Purpose     = "DevBox-with-CustomImage"
    CreatedBy   = "Terraform"
  }
}

# Random string for unique resource naming
resource "random_string" "resource_token" {
  length  = 13
  special = false
  upper   = false
}

# Random UUID for image template GUID
resource "random_uuid" "guid_id" {}

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
  
  image_gallery_name = var.image_gallery_name != "" ? var.image_gallery_name : "${local.abbreviations.compute_galleries}${local.resource_token}"
  
  vnet_name   = var.network_vnet_name != "" ? var.network_vnet_name : "${local.abbreviations.network_virtual_networks}${local.resource_token}"
  subnet_name = var.network_subnet_name != "" ? var.network_subnet_name : "${local.abbreviations.network_virtual_networks_subnets}${local.resource_token}"
  
  # Load devcenter settings
  devcenter_settings = jsondecode(file("${path.module}/devcenter-settings.json"))
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

# Compute Gallery Module
module "gallery" {
  source = "./modules/gallery"
  
  gallery_name           = local.image_gallery_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.main.name
  
  # Multiple image definitions - Packer will create versions in these definitions
  image_definitions = [
    {
      name        = "VisualStudioImage"
      offer       = "windows-ent-cpc"
      publisher   = "MicrosoftWindowsDesktop" 
      sku         = "win11-22h2-ent-cpc-m365-vscode"
    },
    {
      name        = "IntelliJDevImage"
      offer       = "windows-ent-cpc"
      publisher   = "MicrosoftWindowsDesktop"
      sku         = "win11-22h2-ent-cpc-m365-intellij"
    }
  ]
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
  gallery_name                   = module.gallery.gallery_name
  managed_identity_id            = azurerm_user_assigned_identity.main.id
  managed_identity_principal_id  = azurerm_user_assigned_identity.main.principal_id
  image_definition_name          = var.image_definition_name
  image_template_name            = var.image_template_name
  template_identity_id           = module.gallery.template_identity_id
  guid_id                        = random_uuid.guid_id.result
  devcenter_settings            = local.devcenter_settings
  
  depends_on = [
    module.gallery
  ]
}

# Packer image build automation for VS Code image (optional)
resource "null_resource" "packer_build_vscode" {
  count = var.enable_packer_build ? 1 : 0

  # Trigger rebuild when Packer configuration changes
  triggers = {
    packer_config_hash = filemd5("${path.module}/packer/windows-devbox.pkr.hcl")
    variables_hash     = filemd5("${path.module}/packer/variables.pkrvars.hcl")
  }

  # Build the VS Code custom image with Packer
  provisioner "local-exec" {
    command     = "powershell.exe -ExecutionPolicy Bypass -File build-image.ps1 -Action Build -ImageType vscode"
    working_dir = "${path.module}/packer"
  }

  depends_on = [
    module.gallery
  ]
}

# Packer image build automation for IntelliJ image (optional)
resource "null_resource" "packer_build_intellij" {
  count = var.enable_packer_build ? 1 : 0

  # Trigger rebuild when Packer configuration changes
  triggers = {
    packer_config_hash = filemd5("${path.module}/packer/intellij-devbox.pkr.hcl")
    variables_hash     = filemd5("${path.module}/packer/intellij-variables.pkrvars.hcl")
  }

  # Build the IntelliJ custom image with Packer
  provisioner "local-exec" {
    command     = "powershell.exe -ExecutionPolicy Bypass -File build-image.ps1 -Action Build -ImageType intellij"
    working_dir = "${path.module}/packer"
  }

  depends_on = [
    module.gallery,
    null_resource.packer_build_vscode
  ]
}