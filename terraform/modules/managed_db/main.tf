terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.9.0"
    }
  }
}

resource "ovh_cloud_project_database" "postgresql" {
  service_name = var.service_name
  description  = "${var.environment}-postgresql"
  engine       = "postgresql"
  version      = var.pg_version
  plan         = var.plan
  flavor       = var.flavor

  nodes {
    region = var.region
  }
}

# Allow compute instance IP to connect
resource "ovh_cloud_project_database_ip_restriction" "compute" {
  count        = var.allowed_ip != "" ? 1 : 0
  service_name = var.service_name
  engine       = "postgresql"
  cluster_id   = ovh_cloud_project_database.postgresql.id
  ip           = "${var.allowed_ip}/32"
}

# Create application databases
resource "ovh_cloud_project_database_database" "app" {
  service_name = var.service_name
  engine       = "postgresql"
  cluster_id   = ovh_cloud_project_database.postgresql.id
  name         = var.db_name
}

resource "ovh_cloud_project_database_database" "powersync" {
  service_name = var.service_name
  engine       = "postgresql"
  cluster_id   = ovh_cloud_project_database.postgresql.id
  name         = var.db_powersync_name
}

# Create the application database user
resource "ovh_cloud_project_database_postgresql_user" "app" {
  service_name = var.service_name
  cluster_id   = ovh_cloud_project_database.postgresql.id
  name         = var.db_user
  roles        = ["replication"]
}
