terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "1.54.1"
    }
    ovh = {
      source = "ovh/ovh"
      version = "0.44.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
  }
}
