locals {
  oidc_apps = {
    for f in fileset("${path.module}/oidc", "*.yml") :
    trimsuffix(f, ".yml") => yamldecode(file("${path.module}/oidc/${f}"))
  }
}

module "oidc_apps" {
  for_each = local.oidc_apps
  source   = "./modules/oidc_app"

  app_name                     = each.key
  authentik_domain             = "auth.nahsi.dev"
  oidc_defaults                = local.oidc_defaults
  launch_url                   = each.value.launch_url
  ui_group                     = lookup(each.value, "ui_group", "")
  allowed_groups               = each.value.allowed_groups
  redirect_uris                = lookup(each.value, "redirect_uris", [])
  redirect_uris_regex          = lookup(each.value, "redirect_uris_regex", [])
  client_type                  = lookup(each.value, "client_type", "confidential")
  offline_access               = lookup(each.value, "offline_access", false)
  additional_scope_mapping_ids = lookup(each.value, "additional_scope_mapping_ids", [])
  entitlements                 = lookup(each.value, "entitlements", {})
  groups                       = local.groups
}

output "oidc_apps" {
  description = "OIDC app credentials"
  value = {
    for name, app in module.oidc_apps : name => {
      client_id     = app.client_id
      client_secret = app.client_secret
    }
  }
  sensitive = true
}
