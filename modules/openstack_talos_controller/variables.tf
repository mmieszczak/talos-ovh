variable "name" {
  type    = string
  default = "talos"
}

variable "node_count" {
  type    = number
  default = 3
}

variable "flavor" {
  type = string
}

variable "lb_flavor" {
  type    = string
  default = "small"
}

variable "talos_image" {
  type = string
}

variable "public_network_name" {
  type = string
}

variable "network_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "user_data" {
  type = string
}

variable "client_configuration" {
  type = map(any)
}
