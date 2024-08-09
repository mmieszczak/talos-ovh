resource "talos_machine_secrets" "this" {}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.name
  machine_type       = "controlplane"
  cluster_endpoint   = "https://${var.controller_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.kubernetes_version}"
  examples           = false
  docs               = false
  config_patches = concat(
    [
      file("${path.module}/config.yaml"),
      yamlencode({
        machine = {
          certSANs = [var.controller_address]
        }
      }),
    ],
    var.controller_config_patches
  )
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.name
  machine_type       = "worker"
  cluster_endpoint   = "https://${var.controller_address}:6443"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = "v${var.talos_version}"
  kubernetes_version = "v${var.kubernetes_version}"
  examples           = false
  docs               = false
  config_patches = concat(
    [
      file("${path.module}/config.yaml"),
    ],
    var.worker_config_patches
  )
}
