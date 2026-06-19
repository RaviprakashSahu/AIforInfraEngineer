variable "name" {
  description = "Name for resources"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  default = "East US"
}

variable "vm_admin_username" {
  default = "azureuser"
}

variable "vm_admin_password" {
  description = "Strong password for Windows VM"
}