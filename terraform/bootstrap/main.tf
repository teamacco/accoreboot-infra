terraform {
  required_version = ">= 1.5.0"

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }

  # Bootstrap uses local state (chicken-and-egg: can't store state in a bucket
  # that doesn't exist yet). One state file per env, stored locally.
}

# OpenStack Provider - uses OS_* environment variables from SOPS
provider "openstack" {}

# S3 bucket for Terraform state (one per OVH project / environment)
resource "openstack_objectstorage_container_v1" "tfstate" {
  name = var.bucket_name

  metadata = {
    managed_by  = "terraform-bootstrap"
    purpose     = "terraform-state"
    environment = var.environment
  }

  versioning {
    type     = "versions"
    location = "${var.bucket_name}-versions"
  }
}

# Versions container (for state versioning / rollback)
resource "openstack_objectstorage_container_v1" "tfstate_versions" {
  name = "${var.bucket_name}-versions"

  metadata = {
    managed_by  = "terraform-bootstrap"
    purpose     = "terraform-state-versions"
    environment = var.environment
  }
}
