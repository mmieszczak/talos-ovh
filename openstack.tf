// ----------
// Networking
// ----------

data "ovh_cloud_project" "lts" {
  service_name = var.project_id
}

resource "ovh_cloud_project_network_private" "net" {
  service_name = data.ovh_cloud_project.lts.service_name
  name         = "mm-talos"
  regions      = ["WAW1"]
  vlan_id      = 100
}

resource "ovh_cloud_project_network_private_subnet" "subnet" {
  service_name = data.ovh_cloud_project.lts.service_name
  network_id   = ovh_cloud_project_network_private.net.id
  region       = "WAW1"
  start        = "192.168.168.100"
  end          = "192.168.168.200"
  network      = "192.168.168.0/24"
  dhcp         = true
  no_gateway   = false
}

resource "ovh_cloud_project_gateway" "gateway" {
  service_name = ovh_cloud_project_network_private.net.service_name
  name         = "mm-gateway"
  model        = "s"
  region       = ovh_cloud_project_network_private_subnet.subnet.region
  network_id   = tolist(ovh_cloud_project_network_private.net.regions_attributes[*].openstackid)[0]
  subnet_id    = ovh_cloud_project_network_private_subnet.subnet.id
}

data "openstack_networking_network_v2" "public" {
  name = "Ext-Net"
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

resource "openstack_blockstorage_volume_v3" "controller" {
  count    = var.controller_count
  region   = "WAW1"
  name     = "mm-talos-controller-${count.index}"
  size     = 50
  image_id = data.openstack_images_image_v2.talos.id

  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

resource "openstack_compute_instance_v2" "controller" {
  count           = var.controller_count
  name            = "${var.name}-controller-${count.index}"
  security_groups = ["default"]
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  user_data       = data.talos_machine_configuration.controlplane.machine_configuration

  block_device {
    uuid             = openstack_blockstorage_volume_v3.controller[count.index].id
    source_type      = "volume"
    boot_index       = 0
    destination_type = "volume"
  }

  network {
    name = ovh_cloud_project_network_private.net.name
  }

  depends_on = [
    ovh_cloud_project_network_private_subnet.subnet
  ]

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}

resource "openstack_networking_floatingip_v2" "controller" {
  count       = var.controller_count
  pool        = data.openstack_networking_network_v2.public.name
  description = "Floating IP for talos controller node"
}

resource "openstack_compute_floatingip_associate_v2" "controller" {
  count       = var.controller_count
  floating_ip = openstack_networking_floatingip_v2.controller[count.index].address
  instance_id = openstack_compute_instance_v2.controller[count.index].id
  fixed_ip    = openstack_compute_instance_v2.controller[count.index].network[0].fixed_ip_v4

  depends_on = [ovh_cloud_project_gateway.gateway]
}

resource "openstack_blockstorage_volume_v3" "worker" {
  count    = var.worker_count
  region   = "WAW1"
  name     = "mm-talos-worker-${count.index}"
  size     = 50
  image_id = data.openstack_images_image_v2.talos.id

  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

resource "openstack_compute_instance_v2" "worker" {
  count           = var.worker_count
  name            = "${var.name}-worker-${count.index}"
  security_groups = ["default"]
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  user_data       = data.talos_machine_configuration.worker.machine_configuration

  block_device {
    uuid             = openstack_blockstorage_volume_v3.worker[count.index].id
    source_type      = "volume"
    boot_index       = 0
    destination_type = "volume"
  }

  network {
    name = ovh_cloud_project_network_private.net.name
  }

  depends_on = [
    ovh_cloud_project_network_private_subnet.subnet,
    openstack_compute_instance_v2.controller,
  ]

  lifecycle {
    ignore_changes = [
      user_data,
    ]
  }
}
