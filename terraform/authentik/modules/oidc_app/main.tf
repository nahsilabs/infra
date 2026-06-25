terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# ── Signing certificate ─────────────────────────────────

resource "tls_private_key" "signing" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "signing" {
  private_key_pem = tls_private_key.signing.private_key_pem
  subject {
    common_name = var.app_name
  }
  validity_period_hours = 24 * 365 * 10
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "authentik_certificate_key_pair" "signing" {
  name             = "${var.app_name}-signing"
  certificate_data = tls_self_signed_cert.signing.cert_pem
  key_data         = tls_private_key.signing.private_key_pem
}

# ── Data sources ────────────────────────────────────────

resource "random_id" "client_id" {
  byte_length = 8
}

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

# Entitlements scope — only added to the provider when entitlements are defined,
# so apps without entitlements don't depend on the mapping existing.
data "authentik_property_mapping_provider_scope" "entitlements" {
  count   = length(var.entitlements) > 0 ? 1 : 0
  managed = "goauthentik.io/providers/oauth2/scope-entitlements"
}

data "authentik_property_mapping_provider_scope" "offline_access" {
  count   = var.offline_access ? 1 : 0
  managed = "goauthentik.io/providers/oauth2/scope-offline_access"
}

locals {
  entitlement_scope_ids   = length(var.entitlements) > 0 ? [data.authentik_property_mapping_provider_scope.entitlements[0].id] : []
  offline_access_scope_ids = var.offline_access ? [data.authentik_property_mapping_provider_scope.offline_access[0].id] : []

  entitlement_group_bindings = {
    for b in flatten([
      for name, ent in var.entitlements : [
        for g in ent.groups : { entitlement = name, group = g }
      ]
    ]) : "${b.entitlement}/group/${b.group}" => b
  }

  entitlement_user_bindings = {
    for b in flatten([
      for name, ent in var.entitlements : [
        for u in ent.users : { entitlement = name, user = u }
      ]
    ]) : "${b.entitlement}/user/${b.user}" => b
  }

  entitlement_usernames = distinct(flatten([for ent in var.entitlements : ent.users]))
}

# ── Provider + Application ──────────────────────────────

resource "authentik_provider_oauth2" "this" {
  name               = var.app_name
  client_id          = random_id.client_id.hex
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  client_type        = var.client_type
  grant_types        = ["authorization_code"]
  signing_key        = authentik_certificate_key_pair.signing.id
  property_mappings = sort(distinct(concat(
    data.authentik_property_mapping_provider_scope.default.ids,
    var.scopes,
    local.entitlement_scope_ids,
    local.offline_access_scope_ids,
  )))

  allowed_redirect_uris = concat(
    [for url in var.redirect_uris : {
      url               = url
      matching_mode     = "strict"
      redirect_uri_type = "authorization"
    }],
    [for url in var.redirect_uris_regex : {
      url               = url
      matching_mode     = "regex"
      redirect_uri_type = "authorization"
    }],
  )
}

resource "authentik_application" "this" {
  name              = var.app_name
  slug              = var.app_name
  protocol_provider = authentik_provider_oauth2.this.id
  meta_launch_url   = var.launch_url
  group             = var.ui_group
  open_in_new_tab   = true
}

resource "authentik_policy_binding" "access" {
  for_each = toset(var.allowed_groups)
  target   = authentik_application.this.uuid
  group    = var.groups[each.value]
  order    = index(var.allowed_groups, each.value)
}

# ── Entitlements ────────────────────────────────────────

resource "authentik_application_entitlement" "this" {
  for_each    = var.entitlements
  name        = each.key
  application = authentik_application.this.uuid
}

data "authentik_user" "entitlement" {
  for_each = toset(local.entitlement_usernames)
  username = each.value
}

resource "authentik_policy_binding" "entitlement_group" {
  for_each = local.entitlement_group_bindings
  target   = authentik_application_entitlement.this[each.value.entitlement].id
  group    = var.groups[each.value.group]
  order    = 0
}

resource "authentik_policy_binding" "entitlement_user" {
  for_each = local.entitlement_user_bindings
  target   = authentik_application_entitlement.this[each.value.entitlement].id
  user     = data.authentik_user.entitlement[each.value.user].pk
  order    = 0
}
