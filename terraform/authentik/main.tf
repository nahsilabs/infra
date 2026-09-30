terraform {
  required_version = ">= 1.9"

  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "authentik"
    }
  }

  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "= 2026.8.0"
    }
  }
}

provider "authentik" {
  url = "https://auth.nahsi.dev"
}
