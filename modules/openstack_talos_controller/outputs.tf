output "lb_address" {
  value = openstack_networking_floatingip_v2.controller_lb.address
}

output "private_addresses" {
  value = local.controller_private_addresses
}
