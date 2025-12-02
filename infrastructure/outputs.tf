# Infrastructure Outputs
# Managed by Operations Team

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "dev_center_name" {
  description = "The name of the DevCenter"
  value       = module.devcenter.dev_center_name
}

output "project_name" {
  description = "The name of the DevCenter Project"
  value       = module.devcenter.project_name
}

output "location" {
  description = "The location of resources"
  value       = var.location
}

output "gallery_name" {
  description = "The name of the Azure Compute Gallery"
  value       = azurerm_shared_image_gallery.main.name
}

output "gallery_id" {
  description = "The ID of the Azure Compute Gallery"
  value       = azurerm_shared_image_gallery.main.id
}

output "managed_identity_principal_id" {
  description = "The principal ID of the managed identity"
  value       = azurerm_user_assigned_identity.main.principal_id
}

output "subscription_id" {
  description = "The subscription ID"
  value       = data.azurerm_client_config.current.subscription_id
}

output "tenant_id" {
  description = "The tenant ID"
  value       = data.azurerm_client_config.current.tenant_id
}

output "network_connection_name" {
  description = "The name of the network connection"
  value       = local.nc_name
}
