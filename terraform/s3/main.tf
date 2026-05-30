terraform {
  cloud {
    organization = "nahsilabs"

    workspaces {
      name = "s3"
    }
  }

  required_providers {
    minio = {
      source  = "aminueza/minio"
      version = "~> 3.37"
    }
  }
}

provider "minio" {
  minio_server = "s3.nahsi.dev:9000"
  minio_ssl    = true
  s3_compat_mode = true
}
