variable "bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "accoreboot-tfstate"
}

variable "environment" {
  description = "Environment name (passed via TF_VAR_environment)"
  type        = string
}
