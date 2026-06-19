variable "participant_name" {
  description = "Participant name (lowercase, no spaces)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "admin_password" {
  description = "Admin password used for Linux labadmin and Windows Administrator"
  type        = string
  sensitive   = true
}

variable "allowed_admin_cidr" {
  description = "CIDR allowed to connect to the EC2 Instance Connect Endpoint"
  type        = string
  default     = "0.0.0.0/0"
}
