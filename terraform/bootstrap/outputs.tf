output "bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = ovh_cloud_project_storage.tfstate.name
}

output "bucket_region" {
  description = "Region of the bucket"
  value       = ovh_cloud_project_storage.tfstate.region_name
}

output "s3_endpoint" {
  description = "S3 endpoint for backend config"
  value       = "https://s3.${lower(ovh_cloud_project_storage.tfstate.region_name)}.io.cloud.ovh.net/"
}

output "access_key_id" {
  description = "S3 access key ID (put in credentials/common.enc.env as AWS_ACCESS_KEY_ID)"
  value       = ovh_cloud_project_user_s3_credential.tfstate.access_key_id
  sensitive   = true
}

output "secret_access_key" {
  description = "S3 secret access key (put in credentials/common.enc.env as AWS_SECRET_ACCESS_KEY)"
  value       = ovh_cloud_project_user_s3_credential.tfstate.secret_access_key
  sensitive   = true
}
