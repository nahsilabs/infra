resource "authentik_brand" "main" {
  domain              = var.brand.domain
  default             = true
  branding_title      = var.organization_name
  branding_logo       = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_favicon    = "/static/dist/assets/icons/icon.png"
  flow_authentication = authentik_flow.authentication.uuid
  flow_recovery       = var.recovery.enabled ? authentik_flow.recovery[0].uuid : null
  flow_invalidation   = null
  flow_user_settings  = null

  depends_on = [
    authentik_blueprint.default_authentication,
    authentik_blueprint.default_password_change,
    authentik_flow_stage_binding.authentication_identification,
    authentik_flow_stage_binding.authentication_password,
    authentik_flow_stage_binding.authentication_mfa,
    authentik_flow_stage_binding.authentication_login,
  ]
}
