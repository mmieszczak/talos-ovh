variable "name" {
  type = string
}

variable "node_count" {
  type = number
}

variable "image_id" {
  type = string
}

variable "flavor" {
  type = string
}

variable "user_data" {
  type = string
}

variable "network" {
  type = string
}

variable "client_configuration" {
  type = map(any)
}

variable "controller_address" {
  type = string
}

variable "node_labels" {
  type    = map(string)
  default = {}
}

variable "node_taints" {
  type    = map(string)
  default = {}
}
