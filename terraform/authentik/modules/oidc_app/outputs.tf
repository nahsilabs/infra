output "client_id" {
  description = "OIDC client identifier for publication through the application's secret-delivery path."
  value       = authentik_provider_oauth2.this.client_id
  sensitive   = true
}

output "client_secret" {
  description = "Provider client secret. Public clients must not rely on it. Sensitive marking does not encrypt Terraform state."
  value       = authentik_provider_oauth2.this.client_secret
  sensitive   = true
}

output "oidc_config_url" {
  description = "OIDC discovery URL for this application."
  value       = "https://${var.authentik_domain}/application/o/${var.app_name}/.well-known/openid-configuration"
}
