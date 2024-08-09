data "openstack_loadbalancer_flavor_v2" "controller" {
  name = var.lb_flavor
}

data "openstack_networking_network_v2" "private" {
  network_id = var.network_id
}

resource "openstack_lb_loadbalancer_v2" "controller" {
  name                  = "${var.name}-controller"
  flavor_id             = data.openstack_loadbalancer_flavor_v2.controller.id
  vip_network_id        = data.openstack_networking_network_v2.private.id
  vip_subnet_id         = var.subnet_id
  vip_port_id           = openstack_networking_port_v2.controller_lb.id
}

resource "openstack_networking_port_v2" "controller_lb" {
  name           = "${var.name}-controller-lb"
  network_id     = data.openstack_networking_network_v2.private.id
  admin_state_up = "true"

  fixed_ip {
    subnet_id = var.subnet_id
  }
}

resource "openstack_networking_floatingip_v2" "controller_lb" {
  pool        = var.public_network_name
  description = "Floating IP for talos controller load balancer"
}

resource "openstack_networking_floatingip_associate_v2" "controller_lb" {
  floating_ip = openstack_networking_floatingip_v2.controller_lb.address
  port_id     = openstack_networking_port_v2.controller_lb.id
}

resource "openstack_lb_listener_v2" "controller-kubernetes" {
  name            = "${var.name}-controller"
  protocol        = "TCP"
  protocol_port   = 6443
  loadbalancer_id = openstack_lb_loadbalancer_v2.controller.id
}

resource "openstack_lb_pool_v2" "controller-kubernetes" {
  name        = "${var.name}-controller-kubernetes"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.controller-kubernetes.id
}

resource "openstack_lb_monitor_v2" "controller-kubernetes" {
  pool_id     = openstack_lb_pool_v2.controller-kubernetes.id
  delay       = 5
  max_retries = 4
  timeout     = 10
  type        = "TCP"
}

resource "openstack_lb_listener_v2" "controller-talos" {
  name            = "${var.name}-talos"
  protocol        = "TCP"
  protocol_port   = 50000
  loadbalancer_id = openstack_lb_loadbalancer_v2.controller.id
}

resource "openstack_lb_pool_v2" "controller-talos" {
  name        = "${var.name}-controller-talos"
  protocol    = "TCP"
  lb_method   = "ROUND_ROBIN"
  listener_id = openstack_lb_listener_v2.controller-talos.id
}

resource "openstack_lb_monitor_v2" "controller-talos" {
  pool_id     = openstack_lb_pool_v2.controller-talos.id
  delay       = 5
  max_retries = 4
  timeout     = 10
  type        = "TCP"
}
