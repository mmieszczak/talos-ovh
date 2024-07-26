data "openstack_compute_flavor_v2" "flavor" {
  name = var.flavor
}

resource "openstack_blockstorage_volume_v3" "worker" {
  count    = var.node_count
  region   = "WAW1"
  name     = "${var.name}-${count.index}"
  size     = 50
  image_id = var.image_id

  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

resource "openstack_compute_instance_v2" "worker" {
  count               = var.node_count
  name                = "${var.name}-${count.index}"
  security_groups     = ["default"]
  flavor_id           = data.openstack_compute_flavor_v2.flavor.id
  user_data           = var.user_data
  stop_before_destroy = true

  block_device {
    uuid             = openstack_blockstorage_volume_v3.worker[count.index].id
    source_type      = "volume"
    boot_index       = 0
    destination_type = "volume"
  }

  network {
    name = var.network
  }

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = var.node_count
  client_configuration        = var.client_configuration
  machine_configuration_input = var.user_data
  node                        = openstack_compute_instance_v2.worker[count.index].network[0].fixed_ip_v4
  endpoint                    = var.controller_address

  config_patches = [
    yamlencode({
      machine = {
        nodeLabels = var.node_labels,
        nodeTaints = var.node_taints,
      }
    })
  ]
}
