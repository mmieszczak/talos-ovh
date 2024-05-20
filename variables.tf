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
  default = "1.7.1"
}

variable "kubernetes_version" {
  type    = string
  default = "1.29.4"
}

variable "controller_count" {
  type    = number
  default = 3
}

variable "worker_count" {
  type    = number
  default = 3
}
