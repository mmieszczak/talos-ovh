// ----------
// Networking
// ----------

data "ovh_cloud_project" "lts" {
  service_name = "5e5a02028b38427289038b1b51363e78"
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

resource "openstack_networking_floatingip_v2" "master" {
  pool        = data.openstack_networking_network_v2.public.name
  description = "Floating IP for talos master node"
}

resource "openstack_compute_floatingip_associate_v2" "master" {
  floating_ip = openstack_networking_floatingip_v2.master.address
  instance_id = openstack_compute_instance_v2.master.id
  fixed_ip    = openstack_compute_instance_v2.master.network[0].fixed_ip_v4

  depends_on = [ovh_cloud_project_gateway.gateway]
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

resource "openstack_blockstorage_volume_v3" "master" {
  region   = "WAW1"
  name     = "mm-talos-master"
  size     = 50
  image_id = data.openstack_images_image_v2.talos.id
  lifecycle {
    ignore_changes = [
      image_id,
    ]
  }
}

resource "openstack_compute_instance_v2" "master" {
  name            = "${var.name}-master"
  security_groups = ["default"]
  flavor_id       = data.openstack_compute_flavor_v2.small.id
  user_data       = data.talos_machine_configuration.controlplane.machine_configuration

  block_device {
    uuid             = openstack_blockstorage_volume_v3.master.id
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
}

# resource "openstack_compute_floatingip_associate_v2" "master" {
#   floating_ip = openstack_networking_floatingip_v2.master.address
#   instance_id = openstack_compute_instance_v2.master.id
#   fixed_ip    = openstack_compute_instance_v2.master.network[0].fixed_ip_v4
#
#   depends_on = [openstack_networking_router_interface_v2.router_interface_1]
# }
