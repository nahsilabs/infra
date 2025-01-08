terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "stalwart"
    }
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
  }
}

data "cloudflare_zone" "nahsi" {
  name = "nahsi.dev"
}
