terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.54"
    }
  }
}

# SSH Key
resource "openstack_compute_keypair_v2" "main" {
  name       = "${var.environment}-keypair"
  public_key = var.public_key
}

# Security Group
resource "openstack_networking_secgroup_v2" "main" {
  name        = "${var.environment}-secgroup"
  description = "Security group for ${var.environment} environment"
}

resource "openstack_networking_secgroup_rule_v2" "ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = var.allowed_ssh_cidr
  security_group_id = openstack_networking_secgroup_v2.main.id
}

resource "openstack_networking_secgroup_rule_v2" "http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

resource "openstack_networking_secgroup_rule_v2" "https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

resource "openstack_networking_secgroup_rule_v2" "mqtt" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1883
  port_range_max    = 1883
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

resource "openstack_networking_secgroup_rule_v2" "mqtt_ws" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8083
  port_range_max    = 8083
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

resource "openstack_networking_secgroup_rule_v2" "mqtt_tls" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8883
  port_range_max    = 8883
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = openstack_networking_secgroup_v2.main.id
}

# Compute Instance
resource "openstack_compute_instance_v2" "main" {
  name            = "${var.environment}-backend"
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = openstack_compute_keypair_v2.main.name
  security_groups = [openstack_networking_secgroup_v2.main.name]

  user_data = templatefile("${path.module}/templates/cloud-init.yml", {})

  network {
    name = "Ext-Net"
  }

  metadata = {
    environment = var.environment
    managed_by  = "terraform"
  }
}
