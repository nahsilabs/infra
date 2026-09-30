resource "random_id" "client_id" {
  byte_length = 8
}

locals {
  entitlement_scope_ids    = length(var.entitlements) > 0 ? [var.oidc_defaults.entitlement_scope_id] : []
  offline_access_scope_ids = var.offline_access ? [var.oidc_defaults.offline_access_scope_id] : []
}

resource "authentik_provider_oauth2" "this" {
  name                       = var.app_name
  client_id                  = random_id.client_id.hex
  authorization_flow         = var.oidc_defaults.authorization_flow
  invalidation_flow          = var.oidc_defaults.invalidation_flow
  client_type                = var.client_type
  grant_types                = var.offline_access ? ["authorization_code", "refresh_token"] : ["authorization_code"]
  access_code_validity       = "minutes=1"
  access_token_validity      = "minutes=10"
  refresh_token_validity     = "days=30"
  refresh_token_threshold    = "seconds=0"
  signing_key                = authentik_certificate_key_pair.signing.id
  issuer_mode                = "per_provider"
  sub_mode                   = "hashed_user_id"
  include_claims_in_id_token = true
  property_mappings = sort(distinct(concat(
    var.oidc_defaults.default_scope_ids,
    sort(tolist(var.additional_scope_mapping_ids)),
    local.entitlement_scope_ids,
    local.offline_access_scope_ids,
  )))

  allowed_redirect_uris = concat(
    [for url in sort(tolist(var.redirect_uris)) : {
      url               = url
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
    }],
    [for url in sort(tolist(var.redirect_uris_regex)) : {
      url               = url
      matching_mode     = "regex"
      redirect_uri_type = "authorization"
    }],
  )
}

resource "authentik_application" "this" {
  name               = var.app_name
  slug               = var.app_name
  protocol_provider  = authentik_provider_oauth2.this.id
  meta_launch_url    = var.launch_url
  group              = var.ui_group
  open_in_new_tab    = true
  policy_engine_mode = "any"
}
