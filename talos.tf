locals {
  common_machine_config = {
    cluster = {
      # see https://www.talos.dev/v1.7/talos-guides/discovery/
      # see https://www.talos.dev/v1.7/reference/configuration/#clusterdiscoveryconfig
      discovery = {
        enabled = true
        registries = {
          kubernetes = {
            disabled = false
          }
          service = {
            disabled = true
          }
        }
      }
      network = {
        cni = {
          name = "custom"
          urls = [
            "https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/canal.yaml"
          ]
        }
      }
    }
    machine = {
      kubelet = {
        extraArgs = {
          feature-gates = "GracefulNodeShutdown=true"
        }
        extraConfig = {
          shutdownGracePeriod             = "60s"
          shutdownGracePeriodCriticalPods = "60s"
        }
      },
      network = {
        interfaces = [
          {
            deviceSelector = {
              physical = true
            }
            dhcp = true
          }
        ]
      }
    }
  }
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${openstack_networking_floatingip_v2.master.address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v1.7.0"
  kubernetes_version = "v1.27.4"
  examples           = false
  docs               = false
}

resource "talos_machine_configuration_apply" "controlplane" {
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = openstack_networking_floatingip_v2.master.address

  config_patches = [
    yamlencode(local.common_machine_config),
  ]
  depends_on = [
    openstack_compute_floatingip_associate_v2.master
  ]
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = openstack_networking_floatingip_v2.master.address
  depends_on = [
    talos_machine_configuration_apply.controlplane
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    openstack_networking_floatingip_v2.master.address
  ]
}

data "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = openstack_networking_floatingip_v2.master.address
}

resource "local_file" "kubeconfig" {
  content  = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  filename = "${path.module}/kubeconfig"
}

resource "local_file" "talosconfig" {
  content  = data.talos_client_configuration.this.talos_config
  filename = "${path.module}/talosconfig"
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
