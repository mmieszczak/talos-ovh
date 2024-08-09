output "private_network_id" {
  value = data.openstack_networking_network_v2.private.id
}

output "subnet_id" {
  value = ovh_cloud_project_network_private_subnet.subnet.id
}
