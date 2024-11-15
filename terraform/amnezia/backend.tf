terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "amnezia"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}
