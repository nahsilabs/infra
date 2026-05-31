terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "ntfy"
    }
  }

  required_providers {
    ntfy = {
      source  = "StephanMeijer/ntfy"
      version = "~> 0.2"
    }
  }
}

provider "ntfy" {
  url = "https://ntfy.nahsi.dev"
}
