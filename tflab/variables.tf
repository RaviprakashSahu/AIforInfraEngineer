variable "participant_name" {
  description = "Your participant name (lowercase, no spaces)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "vm_admin_username" {
  description = "Admin username for the Windows VM"
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  description = "Admin password for the Windows VM (must be 12+ chars with uppercase, lowercase, number, and special char)"
  type        = string
  sensitive   = true
}