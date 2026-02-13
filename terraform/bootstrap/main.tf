terraform {
  required_version = ">= 1.5.0"

  required_providers {
    ovh = {
      source  = "ovh/ovh"
      version = "~> 2.9.0"
    }
  }

  # Bootstrap uses local state (chicken-and-egg: can't store state in a bucket
  # that doesn't exist yet). One state file per env, stored locally.
}

# OVH Provider - uses TF_VAR_* from SOPS credentials
provider "ovh" {
  endpoint           = var.endpoint
  application_key    = var.application_key
  application_secret = var.application_secret
  consumer_key       = var.consumer_key
}

# Lookup the OpenStack user's OVH numeric ID from username
data "ovh_cloud_project_users" "all" {
  service_name = var.service_name
}

locals {
  ovh_user = [for u in data.ovh_cloud_project_users.all.users : u if u.username == var.os_username][0]
}

# S3 bucket for Terraform state (one per OVH project / environment)
resource "ovh_cloud_project_storage" "tfstate" {
  service_name = var.service_name
  region_name  = var.bucket_region
  name         = var.bucket_name
}

# S3 credentials (generated from the OpenStack user)
resource "ovh_cloud_project_user_s3_credential" "tfstate" {
  service_name = var.service_name
  user_id      = local.ovh_user.user_id
}

# S3 policy: restrict to tfstate bucket only
resource "ovh_cloud_project_user_s3_policy" "tfstate" {
  service_name = var.service_name
  user_id      = local.ovh_user.user_id
  policy = jsonencode({
    "Statement" : [{
      "Sid" : "TFStateBucket",
      "Effect" : "Allow",
      "Action" : [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:ListMultipartUploadParts",
        "s3:ListBucketMultipartUploads",
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
      ],
      "Resource" : [
        "arn:aws:s3:::${var.bucket_name}",
        "arn:aws:s3:::${var.bucket_name}/*"
      ]
    }]
  })
}
