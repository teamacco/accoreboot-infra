# OVH API Credentials
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

# OVH Account
variable "user_id" {
  description = "OVH user ID"
  type        = string
}

variable "service_name" {
  description = "OVH service name (project ID)"
  type        = string
}

# SSH Keys
variable "public_key" {
  description = "SSH public key content"
  type        = string
}

variable "private_key" {
  description = "Path to SSH private key"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

# Environment
variable "environment" {
  description = "Environment name"
  type        = string
  default     = "test"
}

variable "region" {
  description = "OVH region for compute"
  type        = string
  default     = "GRA11"
}

# Compute Instance
variable "flavor_name" {
  description = "OVH instance flavor for backend"
  type        = string
  default     = "b3-8"
}

variable "image_name" {
  description = "OS image name"
  type        = string
  default     = "Ubuntu 24.04"
}

variable "ssh_user" {
  description = "SSH user for the instance"
  type        = string
  default     = "ubuntu"
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed to SSH"
  type        = string
  default     = "0.0.0.0/0"
}

# Managed Database
variable "db_region" {
  description = "OVH region for managed database"
  type        = string
  default     = "GRA"
}

variable "pg_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "17"
}

variable "db_plan" {
  description = "Database plan (essential, business, enterprise)"
  type        = string
  default     = "essential"
}

variable "db_flavor" {
  description = "Database flavor"
  type        = string
  default     = "db1-4"
}
