output "instance_public_ip" {
  description = "Public IP of the backend instance"
  value       = module.compute.public_ip
}

output "instance_name" {
  description = "Name of the backend instance"
  value       = module.compute.instance_name
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh -i ${var.private_key} ${var.ssh_user}@${module.compute.public_ip}"
}

output "db_host" {
  description = "PostgreSQL managed host"
  value       = module.managed_db.db_host
}

output "db_port" {
  description = "PostgreSQL managed port"
  value       = module.managed_db.db_port
}

output "db_uri" {
  description = "PostgreSQL connection URI"
  value       = module.managed_db.db_uri
  sensitive   = true
}

output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory"
  value       = "${path.module}/../../../ansible/inventory/${var.environment}.ini"
}
