terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.54.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.5.0"
    }
  }
}
