variable "name" {
  type    = string
  default = "mm-talos"
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
