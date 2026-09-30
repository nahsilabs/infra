data "authentik_flow" "default_authorization" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default_invalidation" {
  slug = "default-provider-invalidation-flow"
}

data "authentik_property_mapping_provider_scope" "default" {
  managed_list = [
    "goauthentik.io/providers/oauth2/scope-openid",
    "goauthentik.io/providers/oauth2/scope-email",
    "goauthentik.io/providers/oauth2/scope-profile",
  ]
}

data "authentik_property_mapping_provider_scope" "entitlements" {
  count   = anytrue([for app in local.oidc_apps : length(lookup(app, "entitlements", {})) > 0]) ? 1 : 0
  managed = "goauthentik.io/providers/oauth2/scope-entitlements"
}

data "authentik_property_mapping_provider_scope" "offline_access" {
  count   = anytrue([for app in local.oidc_apps : lookup(app, "offline_access", false)]) ? 1 : 0
  managed = "goauthentik.io/providers/oauth2/scope-offline_access"
}

locals {
  oidc_defaults = {
    authorization_flow      = data.authentik_flow.default_authorization.id
    invalidation_flow       = data.authentik_flow.default_invalidation.id
    default_scope_ids       = data.authentik_property_mapping_provider_scope.default.ids
    entitlement_scope_id    = one(data.authentik_property_mapping_provider_scope.entitlements[*].id)
    offline_access_scope_id = one(data.authentik_property_mapping_provider_scope.offline_access[*].id)
  }
}
