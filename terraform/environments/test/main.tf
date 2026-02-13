terraform {
  required_version = ">= 1.5.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.9.0"
    }
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }

  # Remote state on OVH Object Storage (S3-compatible)
  # Bucket created by terraform/bootstrap/
  # Credentials passed via -backend-config at init time
  backend "s3" {
    bucket                      = "accoreboot-tfstate"
    key                         = "test/terraform.tfstate"
    region                      = "gra"
    endpoints = {
      s3 = "https://s3.gra.io.cloud.ovh.net/"
    }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}

# OVH Provider
provider "ovh" {
  endpoint           = var.endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}

# OpenStack Provider - uses OS_* environment variables
provider "openstack" {}

# Backend instance (Node.js + EMQX + PowerSync)
module "compute" {
  source = "../../modules/compute"

  environment      = var.environment
  public_key       = var.public_key
  flavor_name      = var.flavor_name
  image_name       = var.image_name
  allowed_ssh_cidr = var.allowed_ssh_cidr
}

# PostgreSQL managed (TimescaleDB)
module "managed_db" {
  source = "../../modules/managed_db"

  environment  = var.environment
  service_name = var.service_name
  region       = var.db_region
  pg_version   = var.pg_version
  plan         = var.db_plan
  flavor       = var.db_flavor
}

# Generate Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    environment = var.environment
    public_ip   = module.compute.public_ip
    ssh_user    = var.ssh_user
    private_key = var.private_key
    db_host     = module.managed_db.db_host
    db_port     = module.managed_db.db_port
    db_user     = "accoreboot"
    db_password = module.managed_db.db_user_password
  })
  filename = "${path.module}/../../../ansible/inventory/${var.environment}.ini"
}
