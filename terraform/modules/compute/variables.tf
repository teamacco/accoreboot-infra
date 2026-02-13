variable "environment" {
  description = "Environment name (test, preprod, prod)"
  type        = string
}

variable "public_key" {
  description = "SSH public key"
  type        = string
}

variable "flavor_name" {
  description = "OVH instance flavor (b3-8, b3-16, b3-32...)"
  type        = string
  default     = "b3-8"
}

variable "image_name" {
  description = "OS image name"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH"
  type        = string
  default     = "0.0.0.0/0"
}
