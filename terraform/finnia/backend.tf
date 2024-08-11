terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "hcloud"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

data "cloudflare_zone" "nahsi_dev" {
  name = "nahsi.dev"
}
