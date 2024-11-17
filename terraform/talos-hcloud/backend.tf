terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "talos-hcloud"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}
