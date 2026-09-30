resource "authentik_flow" "recovery" {
  count = var.recovery.enabled ? 1 : 0

  designation    = "recovery"
  name           = "recovery"
  slug           = var.recovery.slug
  title          = "Reset your password"
  authentication = "require_unauthenticated"
}

resource "authentik_stage_email" "recovery_email" {
  count = var.recovery.enabled ? 1 : 0

  name                     = "recovery-email"
  use_global_settings      = true
  activate_user_on_success = var.recovery.activate_user_on_success
  timeout                  = 30
  token_expiry             = "hours=24"
  subject                  = "Reset your ${var.organization_name} account"
}

resource "authentik_stage_user_write" "recovery_write" {
  count = var.recovery.enabled ? 1 : 0

  name               = "recovery-write"
  user_creation_mode = "never_create"
}

resource "authentik_stage_user_login" "recovery_login" {
  count = var.recovery.enabled ? 1 : 0

  name             = "recovery-login"
  session_duration = "hours=8"
}

# False excludes identification and email when an admin-restored link is planned.
# Fresh self-service requests must still identify the user and verify their email.
resource "authentik_policy_expression" "skip_if_restored" {
  count = var.recovery.enabled ? 1 : 0

  name       = "recovery-skip-if-restored"
  expression = "return not request.context.get('is_restored', False)"
}

resource "authentik_policy_binding" "skip_if_restored_id" {
  count = var.recovery.enabled ? 1 : 0

  target = authentik_flow_stage_binding.recovery_identification[0].id
  policy = authentik_policy_expression.skip_if_restored[0].id
  order  = 0
}

resource "authentik_policy_binding" "skip_if_restored_email" {
  count = var.recovery.enabled ? 1 : 0

  target = authentik_flow_stage_binding.recovery_email[0].id
  policy = authentik_policy_expression.skip_if_restored[0].id
  order  = 0
}

resource "authentik_flow_stage_binding" "recovery_identification" {
  count = var.recovery.enabled ? 1 : 0

  target                  = authentik_flow.recovery[0].uuid
  stage                   = authentik_stage_identification.identification.id
  order                   = 10
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_email" {
  count = var.recovery.enabled ? 1 : 0

  target                  = authentik_flow.recovery[0].uuid
  stage                   = authentik_stage_email.recovery_email[0].id
  order                   = 20
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_password" {
  count = var.recovery.enabled ? 1 : 0

  target                  = authentik_flow.recovery[0].uuid
  stage                   = authentik_stage_prompt.enrollment_password.id
  order                   = 30
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# Validate existing MFA before any password write.
resource "authentik_flow_stage_binding" "recovery_mfa" {
  count = var.recovery.enabled ? 1 : 0

  target                  = authentik_flow.recovery[0].uuid
  stage                   = authentik_stage_authenticator_validate.mfa.id
  order                   = 40
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_write" {
  count = var.recovery.enabled ? 1 : 0

  target                  = authentik_flow.recovery[0].uuid
  stage                   = authentik_stage_user_write.recovery_write[0].id
  order                   = 50
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_login" {
  count = var.recovery.enabled ? 1 : 0

  target                  = authentik_flow.recovery[0].uuid
  stage                   = authentik_stage_user_login.recovery_login[0].id
  order                   = 100
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}
