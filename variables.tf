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
  default = "1.7.5"
}

variable "talos_image" {
  type    = string
  default = "mm-talos-1-7-5"
}

variable "kubernetes_version" {
  type    = string
  default = "1.27.15"
}

variable "controller_count" {
  type    = number
  default = 3
}

variable "controller_flavor" {
  type    = string
  default = "d2-8"
}

variable "region" {
  type    = string
  default = "WAW1"
}

variable "nodepools" {
  type = map(any)
  default = {
    apps = {
      node_count = 0
      flavor     = "d2-8"
      node_labels = {
        "node.kubernetes.io/role" = "apps"
      }
      node_taints = {}
    },
    services = {
      node_count = 0
      flavor     = "d2-8"
      node_labels = {
        "node.kubernetes.io/role" = "serivces"
      }
      node_taints = {}
    },
  }
}
