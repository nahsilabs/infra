output "client_id" {
  description = "OAuth2 client ID"
  value       = authentik_provider_oauth2.this.client_id
}

output "client_secret" {
  description = "OAuth2 client secret"
  value       = authentik_provider_oauth2.this.client_secret
  sensitive   = true
}

output "oidc_config_url" {
  value       = "https://${var.authentik_domain}/application/o/${var.app_name}/.well-known/openid-configuration"
}
