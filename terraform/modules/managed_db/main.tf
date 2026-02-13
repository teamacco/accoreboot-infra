terraform {
  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 0.40"
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

# Create database user
resource "ovh_cloud_project_database_user" "app" {
  service_name = var.service_name
  engine       = "postgresql"
  cluster_id   = ovh_cloud_project_database.postgresql.id
  name         = var.db_user
}

# Create the application database
resource "ovh_cloud_project_database_postgresql_user" "app" {
  service_name = var.service_name
  cluster_id   = ovh_cloud_project_database.postgresql.id
  name         = var.db_user
  roles        = ["replication"]
}
