locals {
  controller_config_patch = {
    machine = {
      certSANs = [module.controller.lb_address]
    }
    cluster = {
      inlineManifests = [
        {
          name     = "cloud-config"
          contents = file("manifests/secret.yaml")
        },
        {
          name     = "storageclass"
          contents = file("manifests/storageclass.yaml")
        },
      ]
      externalCloudProvider = {
        enabled = true
        manifests = [
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-role-bindings.yaml",
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/cloud-controller-manager-roles.yaml",
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/controller-manager/openstack-cloud-controller-manager-ds.yaml",
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/cinder-csi-plugin/cinder-csi-controllerplugin.yaml",
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/cinder-csi-plugin/cinder-csi-controllerplugin-rbac.yaml",
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/cinder-csi-plugin/cinder-csi-nodeplugin.yaml",
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/cinder-csi-plugin/cinder-csi-nodeplugin-rbac.yaml",
          "https://raw.githubusercontent.com/kubernetes/cloud-provider-openstack/master/manifests/cinder-csi-plugin/csi-cinder-driver.yaml",
        ]
      }
    }
  }
}

module "talos_config" {
  source = "./modules/talos_config"

  name               = var.name
  kubernetes_version = var.kubernetes_version
  talos_version      = var.talos_version
  controller_address = module.controller.lb_address
  controller_config_patches = [
    yamlencode(local.controller_config_patch),
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.name
  client_configuration = module.talos_config.client_configuration
  endpoints            = [module.controller.lb_address]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = module.talos_config.client_configuration
  node                 = module.controller.private_addresses[0]
  endpoint             = module.controller.lb_address

  depends_on = [
    module.controller,
  ]
}

data "talos_cluster_kubeconfig" "this" {
  client_configuration = module.talos_config.client_configuration
  node                 = module.controller.private_addresses[0]
  endpoint             = module.controller.lb_address

  depends_on = [
    talos_machine_bootstrap.this,
  ]
}

resource "local_file" "kubeconfig" {
  content  = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}

resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/talosconfig"
}

# output "talosconfig" {
#   value     = data.talos_client_configuration.this.talos_config
#   sensitive = true
# }
#
# output "kubeconfig" {
#   value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
#   sensitive = true
# }
