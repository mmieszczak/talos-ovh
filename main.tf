module "network" {
  source = "./modules/ovh_network"

  name       = var.name
  region     = var.region
  project_id = var.project_id
}

module "controller" {
  source = "./modules/openstack_talos_controller"

  name                 = var.name
  flavor               = var.controller_flavor
  node_count           = var.controller_count
  public_network_name  = "Ext-Net"
  network_id           = module.network.private_network_id
  subnet_id            = module.network.subnet_id
  user_data            = module.talos_config.contorller_user_data
  talos_image          = var.talos_image
  client_configuration = module.talos_config.client_configuration

  depends_on = [
    module.network,
  ]
}

module "nodepool" {
  for_each = tomap(var.nodepools)
  source   = "./modules/openstack_talos_worker"

  name       = each.key
  node_count = each.value.node_count
  flavor     = each.value.flavor
  region     = var.region

  node_labels = each.value.node_labels
  node_taints = each.value.node_taints

  talos_image          = var.talos_image
  user_data            = module.talos_config.worker_user_data
  network_id           = module.network.private_network_id
  controller_address   = module.controller.lb_address
  client_configuration = module.talos_config.client_configuration

  depends_on = [
    module.controller,
  ]
}
