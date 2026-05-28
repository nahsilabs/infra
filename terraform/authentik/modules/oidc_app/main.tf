terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.2"
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

# ── Provider + Application ──────────────────────────────

resource "authentik_provider_oauth2" "this" {
  name               = var.app_name
  client_id          = random_id.client_id.hex
  authorization_flow = data.authentik_flow.default_authorization.id
  invalidation_flow  = data.authentik_flow.default_invalidation.id
  client_type        = "confidential"
  signing_key        = authentik_certificate_key_pair.signing.id
  property_mappings  = sort(distinct(concat(data.authentik_property_mapping_provider_scope.default.ids, var.scopes)))

  allowed_redirect_uris = [for uri in var.redirect_uris : {
    url           = uri.url
    matching_mode = uri.matching_mode
  }]
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
  for_each = { for idx, gid in var.allowed_groups : idx => gid }
  target   = authentik_application.this.uuid
  group    = each.value
  order    = each.key
}
