terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "google"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7"
    }
  }
}

provider "google" {
  project = var.project_id

  # Route API calls' quota to our project (required when authenticating with
  # user ADC rather than a service account).
  billing_project       = var.project_id
  user_project_override = true
}

variable "project_id" {
  type        = string
  default     = "main-501817"
  description = "GCP project ID this workspace manages resources in."
}
