output "instance_id" {
  description = "Instance ID"
  value       = openstack_compute_instance_v2.main.id
}

output "instance_name" {
  description = "Instance name"
  value       = openstack_compute_instance_v2.main.name
}

output "public_ip" {
  description = "Public IP address"
  value       = openstack_compute_instance_v2.main.access_ip_v4
}

output "security_group_id" {
  description = "Security group ID"
  value       = openstack_networking_secgroup_v2.main.id
}
