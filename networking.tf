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
