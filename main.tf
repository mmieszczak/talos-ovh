variable "name" {
  type    = string
  default = "mm-talos"
}

// ----------
// Networking
// ----------

resource "openstack_networking_network_v2" "default" {
  name           = var.name
  admin_state_up = "true"
}

resource "openstack_networking_subnet_v2" "default" {
  name       = var.name
  network_id = openstack_networking_network_v2.default.id
  cidr       = "10.10.10.0/24"
  ip_version = 4
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

// -----
// Talos
// -----

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.name
  machine_type     = "controlplane"
  cluster_endpoint = "https://${openstack_networking_floatingip_v2.master.address}:6443"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  # node                        = openstack_compute_instance_v2.master.network[0].fixed_ip_v4
  node = openstack_networking_floatingip_v2.master.address
  config_patches = [
    templatefile("${path.module}/templates/install-disk-and-hostname.yaml.tmpl", {
      hostname     = "${var.name}-cp"
      install_disk = "/dev/vda"
    }),
    file("${path.module}/files/cp-scheduling.yaml"),
  ]
  depends_on = [
    openstack_compute_floatingip_associate_v2.master
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = openstack_networking_floatingip_v2.master.address
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
}

// -------
// Outputs
// -------

data "talos_client_configuration" "this" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    openstack_networking_floatingip_v2.master.address
  ]
}

data "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = openstack_networking_floatingip_v2.master.address
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
