variable "name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "controller_address" {
  type = string
}

variable "controller_config_patches" {
  type    = list(string)
  default = []
}

variable "worker_config_patches" {
  type    = list(string)
  default = []
}
