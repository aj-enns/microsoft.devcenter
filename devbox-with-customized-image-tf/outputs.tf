output "devcenter_name" {
  description = "The name of the DevCenter"
  value       = module.devcenter.devcenter_name
}

output "project_name" {
  description = "The name of the DevCenter project"
  value       = module.devcenter.project_name
}

output "network_connection_name" {
  description = "The name of the network connection"
  value       = module.devcenter.network_connection_name
}

output "vnet_name" {
  description = "The name of the virtual network"
  value       = var.existing_subnet_id == "" ? module.vnet[0].vnet_name : ""
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = var.existing_subnet_id == "" ? module.vnet[0].subnet_name : ""
}

output "customized_image_devbox_definitions" {
  description = "The name of the customized image DevBox definition"
  value       = module.devcenter.customized_image_devbox_definitions
}

output "customized_image_pools" {
  description = "The list of customized image pools"
  value       = module.devcenter.customized_image_pools
}