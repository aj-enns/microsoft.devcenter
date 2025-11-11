variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "user_principal_id" {
  description = "The user or group id that will be granted to Devcenter Dev Box User and Deployment Environments User role"
  type        = string
  default     = ""
}

variable "user_principal_type" {
  description = "The type of principal id: User or Group"
  type        = string
  default     = "User"
  validation {
    condition     = contains(["Group", "User", "ServicePrincipal"], var.user_principal_type)
    error_message = "The user_principal_type value must be one of: Group, User, ServicePrincipal."
  }
}

variable "location" {
  description = "Primary location for all resources e.g. eastus"
  type        = string
  default     = "eastus"
}

variable "suffix" {
  description = "The suffix of the resource name. It will be used to generate the resource name. e.g. devcenter-default"
  type        = string
  default     = "default"
}

variable "devcenter_name" {
  description = "The name of Dev Center e.g. dc-devbox-test"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "The name of Dev Center project e.g. dcprj-devbox-test"
  type        = string
  default     = ""
}

variable "network_connection_name" {
  description = "The name of Network Connection e.g. con-devbox-test"
  type        = string
  default     = ""
}

variable "user_identity_name" {
  description = "The name of Dev Center user identity"
  type        = string
  default     = ""
}

variable "network_vnet_name" {
  description = "The name of the Virtual Network e.g. vnet-dcprj-devbox-test-eastus"
  type        = string
  default     = ""
}

variable "network_subnet_name" {
  description = "the subnet name of Dev Box e.g. default"
  type        = string
  default     = ""
}

variable "network_vnet_address_prefixes" {
  description = "The vnet address prefixes of Dev Box e.g. 10.4.0.0/16"
  type        = string
  default     = "10.4.0.0/16"
}

variable "network_subnet_address_prefixes" {
  description = "The subnet address prefixes of Dev Box e.g. 10.4.0.0/24"
  type        = string
  default     = "10.4.0.0/24"
}

variable "image_gallery_name" {
  description = "The name of Azure Compute Gallery"
  type        = string
  default     = ""
}

variable "image_definition_name" {
  description = "The name of Azure Compute Gallery image definition"
  type        = string
  default     = "CustomizedImage"
}

variable "image_template_name" {
  description = "The name of image template for customized image"
  type        = string
  default     = "CustomizedImageTemplate"
}

variable "image_offer" {
  description = "The name of image offer"
  type        = string
  default     = "windows-ent-cpc"
}

variable "image_publisher" {
  description = "The name of image publisher"
  type        = string
  default     = "MicrosoftWindowsDesktop"
}

variable "image_sku" {
  description = "The name of image sku"
  type        = string
  default     = "win11-22h2-ent-cpc-m365"
}

variable "existing_subnet_id" {
  description = "The subnet resource id if the user wants to use existing subnet"
  type        = string
  default     = ""
}