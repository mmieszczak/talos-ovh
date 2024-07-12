variable "name" {
  type    = string
  default = "mm-talos"
}

variable "project_id" {
  type    = string
  default = "5e5a02028b38427289038b1b51363e78"
}

variable "talos_version" {
  type    = string
  default = "1.7.4"
}

variable "kubernetes_version" {
  type    = string
  default = "1.27.15"
}

variable "controller_count" {
  type    = number
  default = 3
}

variable "nodepools" {
  type = map(any)
  default = {
    apps = {
      node_count = 5
      flavor     = "d2-8"
      node_labels = {
        "node.kubernetes.io/role" = "apps"
      }
      node_taints = {}
    },
    services = {
      node_count = 3
      flavor     = "d2-8"
      node_labels = {
        "node.kubernetes.io/role" = "serivces"
      }
      node_taints = {}
    },
  }
}
