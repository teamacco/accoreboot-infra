variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "accoreboot-tfstate"
}

variable "bucket_region" {
  description = "OVH region for the S3 bucket"
  type        = string
  default     = "GRA"
}

variable "environment" {
  description = "Environment name (passed via -var at CLI)"
  type        = string
}

# OVH API credentials (from SOPS: TF_VAR_*)
variable "endpoint" {
  description = "OVH API endpoint"
  type        = string
  default     = "ovh-eu"
}

variable "application_key" {
  description = "OVH application key"
  type        = string
  sensitive   = true
}

variable "application_secret" {
  description = "OVH application secret"
  type        = string
  sensitive   = true
}

variable "consumer_key" {
  description = "OVH consumer key"
  type        = string
  sensitive   = true
}

# OVH project (from SOPS: TF_VAR_service_name)
variable "service_name" {
  description = "OVH Public Cloud project ID"
  type        = string
}

# OpenStack username (from SOPS: OS_USERNAME -> TF_VAR_os_username)
variable "os_username" {
  description = "OpenStack username (used to lookup OVH numeric user ID)"
  type        = string
}
