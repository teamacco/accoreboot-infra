output "bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = openstack_objectstorage_container_v1.tfstate.name
}

output "bucket_region" {
  description = "Region of the bucket"
  value       = "eu-west-par"
}

output "s3_endpoint" {
  description = "S3 endpoint for backend config"
  value       = "https://s3.eu-west-par.io.cloud.ovh.net/"
}
