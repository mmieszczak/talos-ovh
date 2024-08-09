terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "2.0.0"
    }
    ovh = {
      source = "ovh/ovh"
      version = "0.44.0"
    }
  }
}
