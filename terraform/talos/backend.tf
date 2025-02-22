terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "talos"
    }
  }

  required_providers {
    adguard = {
      source  = "gmichels/adguard"
      version = "~> 1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.7"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.16"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = local_sensitive_file.kubeconfig.filename
  }
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
