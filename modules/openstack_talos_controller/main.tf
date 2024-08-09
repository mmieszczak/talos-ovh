data "openstack_images_image_v2" "talos" {
  name        = var.talos_image
  most_recent = true
}

data "openstack_compute_flavor_v2" "small" {
  name = var.flavor
}

resource "openstack_blockstorage_volume_v3" "controller" {
  count    = var.node_count
  region   = var.region
  name     = "${var.name}-controller-${count.index}"
  size     = 50
  image_id = data.openstack_images_image_v2.talos.id

  lifecycle {
    ignore_changes = [
      # Don't recreate the volume if the default image changes,
      # as it would wipe out etcd data on the controller.
      image_id,
    ]
  }
}

resource "openstack_networking_port_v2" "controller" {
  count          = var.node_count
  name           = "${var.name}-controllex-${count.index}"
  network_id     = data.openstack_networking_network_v2.private.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id = var.subnet_id
  }
}

resource "openstack_compute_instance_v2" "controller" {
  count               = var.node_count
  name                = "${var.name}-controller-${count.index}"
  security_groups     = ["default"]
  flavor_id           = data.openstack_compute_flavor_v2.small.id
  user_data           = var.user_data
  stop_before_destroy = true

  block_device {
    uuid             = openstack_blockstorage_volume_v3.controller[count.index].id
    source_type      = "volume"
    boot_index       = 0
    destination_type = "volume"
  }

  network {
    port = openstack_networking_port_v2.controller[count.index].id
  }

  lifecycle {
    ignore_changes = [
      # Don't recreate the instance if the user_data changes,
      # since we apply these changes with confuguration_apply resource anyway.
      user_data,
    ]
  }
}

resource "openstack_lb_member_v2" "controller-kubernetes" {
  count         = var.node_count
  name          = "${var.name}-controller-${count.index}-kubernetes"
  pool_id       = openstack_lb_pool_v2.controller-kubernetes.id
  address       = local.controller_private_addresses[count.index]
  protocol_port = 6443
}

resource "openstack_lb_member_v2" "controller-talos" {
  count         = var.node_count
  name          = "${var.name}-controller-${count.index}-talos"
  pool_id       = openstack_lb_pool_v2.controller-talos.id
  address       = local.controller_private_addresses[count.index]
  protocol_port = 50000
}

resource "talos_machine_configuration_apply" "controlplane" {
  count                       = var.node_count
  client_configuration        = var.client_configuration
  machine_configuration_input = var.user_data
  node                        = local.controller_private_addresses[count.index]
  endpoint                    = local.controller_lb_address

  depends_on = [
    openstack_lb_member_v2.controller-talos,
  ]
}

locals {
  controller_lb_address        = openstack_networking_floatingip_v2.controller_lb.address
  controller_private_addresses = openstack_networking_port_v2.controller[*].all_fixed_ips[0]
}
