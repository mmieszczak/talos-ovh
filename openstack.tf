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

data "openstack_networking_network_v2" "private" {
  name = ovh_cloud_project_network_private.net.name
}

// ------------
// Loadbalancer
// ------------

data "openstack_loadbalancer_flavor_v2" "controller" {
  name = "small"
}

resource "openstack_lb_loadbalancer_v2" "controller" {
  name           = "mm-talos-controller"
  flavor_id      = data.openstack_loadbalancer_flavor_v2.controller.id
  vip_network_id = data.openstack_networking_network_v2.private.id
  vip_subnet_id  = ovh_cloud_project_network_private_subnet.subnet.id
  vip_port_id    = openstack_networking_port_v2.controller_lb.id
}

resource "openstack_networking_port_v2" "controller_lb" {
  name           = "mm-talos-controller-lb"
  network_id     = data.openstack_networking_network_v2.private.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id = ovh_cloud_project_network_private_subnet.subnet.id
  }
}

resource "openstack_networking_floatingip_v2" "controller_lb" {
  pool        = data.openstack_networking_network_v2.public.name
  description = "Floating IP for talos controller load balancer"
}

resource "openstack_networking_floatingip_associate_v2" "controller_lb" {
  floating_ip = openstack_networking_floatingip_v2.controller_lb.address
  port_id     = openstack_networking_port_v2.controller_lb.id
}

resource "openstack_lb_listener_v2" "controller" {
  name            = "mm-talos-controller"
  protocol        = "TCP"
  protocol_port   = 6443
  loadbalancer_id = openstack_lb_loadbalancer_v2.controller.id
}

resource "openstack_lb_pool_v2" "mm-talos-controller" {
  name        = "mm-talos-controller"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.controller.id
}

resource "openstack_lb_monitor_v2" "controller" {
  pool_id     = openstack_lb_pool_v2.mm-talos-controller.id
  delay       = 5
  max_retries = 4
  timeout     = 10
  type        = "TCP"
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
  count               = var.controller_count
  name                = "${var.name}-controller-${count.index}"
  security_groups     = ["default"]
  flavor_id           = data.openstack_compute_flavor_v2.small.id
  user_data           = data.talos_machine_configuration.controlplane.machine_configuration
  stop_before_destroy = true

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
    ovh_cloud_project_network_private_subnet.subnet,
    ovh_cloud_project_gateway.gateway,
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
}

resource "openstack_lb_member_v2" "controller" {
  count         = var.controller_count
  name          = "mm-talos-controller-${count.index}"
  pool_id       = openstack_lb_pool_v2.mm-talos-controller.id
  address       = openstack_compute_instance_v2.controller[count.index].network[0].fixed_ip_v4
  protocol_port = 6443
}

// nodepool
module "apps" {
  for_each   = tomap(var.nodepools)
  name       = "${var.name}-${each.key}"
  source     = "./modules/worker"
  node_count = each.value.node_count
  flavor     = each.value.flavor

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints

  image_id             = data.openstack_images_image_v2.talos.id
  user_data            = data.talos_machine_configuration.worker.machine_configuration
  network              = ovh_cloud_project_network_private.net.name
  controller_address   = openstack_networking_floatingip_v2.controller[0].address
  client_configuration = talos_machine_secrets.this.client_configuration
}
