variable "environment" {
  description = "Environment name (test, preprod, prod)"
  type        = string
}

variable "service_name" {
  description = "OVH project ID"
  type        = string
}

variable "region" {
  description = "OVH region for the database"
  type        = string
  default     = "GRA"
}

variable "pg_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "17"
}

variable "plan" {
  description = "Database plan (essential, business, enterprise)"
  type        = string
  default     = "essential"
}

variable "flavor" {
  description = "Database flavor (db1-4, db1-7, db1-15...)"
  type        = string
  default     = "db1-4"
}

variable "db_user" {
  description = "Application database user"
  type        = string
  default     = "accoreboot"
}

variable "db_name" {
  description = "Application database name"
  type        = string
  default     = "accoreboot"
}

variable "db_powersync_name" {
  description = "PowerSync storage database name"
  type        = string
  default     = "powersync_storage"
}

variable "allowed_ip" {
  description = "IP address allowed to connect (e.g. compute instance public IP)"
  type        = string
  default     = ""
}
