locals {
  machine_config = {
    cluster = {
      network = {
        cni = {
          name = "custom"
          urls = [
            "https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/canal.yaml"
          ]
        }
      }
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
      apiServer = {
        admissionControl = [{
          name = "PodSecurity"
          configuration = {
            apiVersion = "pod-security.admission.config.k8s.io/v1alpha1"
            kind       = "PodSecurityConfiguration"
            defaults = {
              enforce         = "privileged"
              enforce-version = "latest"
              audit           = "baseline"
              audit-version   = "latest"
              warn            = "baseline"
              warn-version    = "latest"
            }
          }
        }]
      }
    }
    machine = {
      features = {
        hostDNS = {
          enabled            = true
          resolveMemberNames = true
        }
      }
      network = {
        nameservers = [
          "1.1.1.1",
          "1.0.0.1",
        ]
      }
      kubelet = {
        extraArgs = {
          feature-gates = "GracefulNodeShutdown=true"
        }
        extraConfig = {
          shutdownGracePeriod             = "60s"
          shutdownGracePeriodCriticalPods = "60s"
        }
      }
      sysctls = {
        "fs.inotify.max_user_watches"   = "65536"
        "fs.inotify.max_user_instances" = "1024"
      }
    }
  }
  controller_lb_address        = openstack_networking_floatingip_v2.controller_lb.address
  controller_private_addresses = openstack_networking_port_v2.controller[*].all_fixed_ips[0]
}

resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${local.controller_lb_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.kubernetes_version}"
  examples           = false
  docs               = false
  config_patches = [
    yamlencode(local.machine_config),
    yamlencode({
      machine = {
        certSANs = [local.controller_lb_address]
      }
    }),
  ]
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.name
  machine_type       = "worker"
  cluster_endpoint   = "https://${local.controller_lb_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.kubernetes_version}"
  examples           = false
  docs               = false
  config_patches = [
    yamlencode(local.machine_config),
  ]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [local.controller_lb_address]
}

resource "talos_machine_configuration_apply" "controlplane" {
  count                       = var.controller_count
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = local.controller_private_addresses[count.index]
  endpoint                    = local.controller_lb_address
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controller_private_addresses[0]
  endpoint             = local.controller_lb_address
}

data "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controller_private_addresses[0]
  endpoint             = local.controller_lb_address
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
