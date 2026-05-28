output "client_id" {
  description = "OAuth2 client ID"
  value       = authentik_provider_oauth2.this.client_id
}

output "client_secret" {
  description = "OAuth2 client secret"
  value       = authentik_provider_oauth2.this.client_secret
  sensitive   = true
}

output "oidc_discovery_url" {
  description = "OIDC discovery endpoint"
  value       = "https://${var.authentik_domain}/application/o/${var.app_name}/"
}

output "authorize_url" {
  description = "OAuth2 authorization endpoint"
  value       = "https://${var.authentik_domain}/application/o/authorize/"
}

output "token_url" {
  description = "OAuth2 token endpoint"
  value       = "https://${var.authentik_domain}/application/o/token/"
}

output "userinfo_url" {
  description = "OIDC userinfo endpoint"
  value       = "https://${var.authentik_domain}/application/o/userinfo/"
}

output "logout_url" {
  description = "OIDC end-session endpoint"
  value       = "https://${var.authentik_domain}/application/o/${var.app_name}/end-session/"
}

output "provider_pk" {
  description = "Provider PK (needed for grant_types API workaround)"
  value       = authentik_provider_oauth2.this.id
}
