locals {
  apps = {
    for f in fileset("${path.module}/apps", "*.yml") :
    trimsuffix(f, ".yml") => yamldecode(file("${path.module}/apps/${f}"))
  }
}

module "s3_apps" {
  for_each = local.apps
  source   = "./modules/s3_app"

  bucket = each.key
  config = each.value
}

output "s3_apps" {
  description = "S3 app credentials"
  value = {
    for name, app in module.s3_apps : name => {
      bucket     = app.bucket
      access_key = app.access_key
      secret_key = app.secret_key
    }
  }
  sensitive = true
}
