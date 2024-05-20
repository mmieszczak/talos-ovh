// ----------
// Networking
// ----------

resource "openstack_networking_network_v2" "default" {
  name           = var.name
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "default" {
  name            = var.name
  network_id      = openstack_networking_network_v2.default.id
  cidr            = "10.10.10.0/24"
  ip_version      = 4
  enable_dhcp     = true
  dns_nameservers = ["8.8.8.8", "8.8.4.4"]
  no_gateway      = true
}

data "openstack_networking_network_v2" "public" {
  name = "Ext-Net"
}

resource "openstack_networking_router_v2" "default" {
  name                = var.name
  admin_state_up      = true
  external_network_id = data.openstack_networking_network_v2.public.id
}

resource "openstack_networking_router_interface_v2" "router_interface_1" {
  router_id = openstack_networking_router_v2.default.id
  subnet_id = openstack_networking_subnet_v2.default.id
}

resource "openstack_compute_secgroup_v2" "master" {
  name        = "${var.name}-master"
  description = "a security group"

  rule {
    from_port   = 6443
    to_port     = 6443
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }

  rule {
    from_port   = 50000
    to_port     = 50000
    ip_protocol = "tcp"
    cidr        = "0.0.0.0/0"
  }
}

resource "openstack_networking_port_v2" "master" {
  name               = "${var.name}-master"
  network_id         = openstack_networking_network_v2.default.id
  admin_state_up     = "true"
  security_group_ids = [openstack_compute_secgroup_v2.master.id]

  fixed_ip {
    subnet_id  = openstack_networking_subnet_v2.default.id
    ip_address = "10.10.10.10"
  }
}

resource "openstack_networking_floatingip_v2" "master" {
  pool        = data.openstack_networking_network_v2.public.name
  description = "Floating IP for talos master node"
}

// -------
// Compute
// -------

data "openstack_images_image_v2" "talos" {
  name        = "mm-talos"
  most_recent = true
}

data "openstack_compute_flavor_v2" "small" {
  name = "d2-4"
}

resource "openstack_compute_instance_v2" "master" {
  name            = "${var.name}-master"
  image_id        = data.openstack_images_image_v2.talos.id
  security_groups = [openstack_compute_secgroup_v2.master.name]
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  user_data       = data.talos_machine_configuration.controlplane.machine_configuration

  network {
    port = openstack_networking_port_v2.master.id
  }
}

resource "openstack_compute_floatingip_associate_v2" "master" {
  floating_ip = openstack_networking_floatingip_v2.master.address
  instance_id = openstack_compute_instance_v2.master.id
  fixed_ip    = openstack_compute_instance_v2.master.network[0].fixed_ip_v4

  depends_on = [openstack_networking_router_interface_v2.router_interface_1]
}
