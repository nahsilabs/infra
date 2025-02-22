terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "dns"
    }
  }

  required_providers {
    adguard = {
      source  = "gmichels/adguard"
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

provider "adguard" {
  host     = "10.2.1.1:3000"
  username = var.adguard_username
  password = var.adguard_password
  scheme   = "http"
}

variable "adguard_username" {
  type = string
}

variable "adguard_password" {
  type      = string
  sensitive = true
}
