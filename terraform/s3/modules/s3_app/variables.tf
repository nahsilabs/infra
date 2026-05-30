variable "bucket" {
  description = "Bucket name"
  type        = string
}

variable "config" {
  description = "App configuration from YAML"
  type        = any
}

locals {
  acl           = lookup(var.config, "acl", "private")
  versioning    = lookup(var.config, "versioning", false)
  force_destroy = lookup(var.config, "force_destroy", false)
  quota_gib     = lookup(var.config, "quota_gib", 0)

  lifecycle_rules = lookup(var.config, "lifecycle_rules", [])
}
