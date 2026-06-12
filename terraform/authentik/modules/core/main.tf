terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2026.5"
    }
  }
}

# ── Groups ──────────────────────────────────────────────

resource "authentik_group" "superusers" {
  name         = "superusers"
  is_superuser = true
  lifecycle { ignore_changes = [users] }
}

resource "authentik_group" "extra" {
  for_each = var.extra_groups
  name     = each.value
  lifecycle { ignore_changes = [users] }
}

# ── Authentication flow ─────────────────────────────────

resource "authentik_flow" "authentication" {
  designation    = "authentication"
  name           = "authentication"
  slug           = "nahsilabs-authentication"
  title          = "${var.organization_name} Login"
  authentication = "require_unauthenticated"
}

data "authentik_source" "inbuilt" {
  managed = "goauthentik.io/sources/inbuilt"
}

resource "authentik_stage_identification" "id" {
  name          = "identification"
  user_fields   = ["username", "email"]
  sources       = [data.authentik_source.inbuilt.uuid]
  recovery_flow = authentik_flow.recovery.uuid
}

resource "authentik_stage_password" "password" {
  name     = "password"
  backends = ["authentik.core.auth.InbuiltBackend"]
}

resource "authentik_stage_user_login" "login" {
  name                     = "login"
  session_duration         = var.session_duration
  terminate_other_sessions = true
}

# ── MFA ─────────────────────────────────────────────────

resource "authentik_stage_authenticator_totp" "totp_setup" {
  name          = "totp-setup"
  digits        = "6"
  friendly_name = "TOTP"
}

resource "authentik_stage_authenticator_validate" "mfa" {
  name                  = "mfa-validate"
  device_classes        = ["totp"]
  not_configured_action = "configure"
  configuration_stages  = sort([authentik_stage_authenticator_totp.totp_setup.id])
}

# ── Expression policies ─────────────────────────────────

resource "authentik_policy_expression" "not_app_password" {
  name       = "not-app-password"
  expression = "return context.get('auth_method') != 'app_password'"
}

# ── Authentication flow bindings ────────────────────────

resource "authentik_flow_stage_binding" "auth_id" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_identification.id.id
  order  = 10
}

resource "authentik_flow_stage_binding" "auth_password" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_password.password.id
  order  = 20
}

resource "authentik_flow_stage_binding" "auth_mfa" {
  target               = authentik_flow.authentication.uuid
  stage                = authentik_stage_authenticator_validate.mfa.id
  order                = 30
  policy_engine_mode   = "all"
  evaluate_on_plan     = false
  re_evaluate_policies = true
}

resource "authentik_policy_binding" "mfa_skip_app_password" {
  target = authentik_flow_stage_binding.auth_mfa.id
  policy = authentik_policy_expression.not_app_password.id
  order  = 0
}

resource "authentik_flow_stage_binding" "auth_login" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_user_login.login.id
  order  = 40
}

# ── Recovery flow ───────────────────────────────────────

resource "authentik_flow" "recovery" {
  designation    = "recovery"
  name           = "recovery"
  slug           = "nahsilabs-recovery"
  title          = "Reset your password"
  authentication = "require_unauthenticated"
}

resource "authentik_stage_email" "recovery_email" {
  name                     = "recovery-email"
  use_global_settings      = true
  activate_user_on_success = true
  timeout                  = 30
  token_expiry             = "hours=24"
  subject                  = "Reset your ${var.organization_name} account"
}

resource "authentik_stage_prompt_field" "password" {
  field_key              = "password"
  label                  = "New password"
  name                   = "recovery-password-field"
  type                   = "password"
  placeholder            = "Password"
  required               = true
  order                  = 0
  placeholder_expression = false
}

resource "authentik_stage_prompt" "recovery_password" {
  name = "recovery-password-prompt"
  fields = [
    authentik_stage_prompt_field.password.id,
  ]
  validation_policies = sort([
    authentik_policy_password.length.id,
    authentik_policy_password.pwned.id,
    authentik_policy_password.complexity.id,
  ])
}

resource "authentik_policy_password" "length" {
  name          = "password-min-length"
  length_min    = 16
  error_message = "Password must be at least 16 characters."
}

resource "authentik_policy_password" "pwned" {
  name                    = "password-pwned"
  check_have_i_been_pwned = true
  error_message           = "Password is in a known breach database."
}

resource "authentik_policy_password" "complexity" {
  name          = "password-complexity"
  check_zxcvbn  = true
  error_message = "Password is not strong enough."
}

resource "authentik_stage_user_write" "recovery_write" {
  name               = "recovery-write"
  user_creation_mode = "never_create"
}

resource "authentik_stage_user_login" "recovery_login" {
  name             = "recovery-login"
  session_duration = "hours=8"
}

# ── Skip-if-restored policy ─────────────────────────────
# When user clicks recovery link, skip identification and email stages

resource "authentik_policy_expression" "skip_if_restored" {
  name       = "recovery-skip-if-restored"
  expression = "return bool(request.context.get('is_restored', True))"
}

resource "authentik_policy_binding" "skip_if_restored_id" {
  target = authentik_flow_stage_binding.recovery_id.id
  policy = authentik_policy_expression.skip_if_restored.id
  order  = 0
}

resource "authentik_policy_binding" "skip_if_restored_email" {
  target = authentik_flow_stage_binding.recovery_email.id
  policy = authentik_policy_expression.skip_if_restored.id
  order  = 0
}

# ── Recovery flow bindings ──────────────────────────────

resource "authentik_flow_stage_binding" "recovery_id" {
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_identification.id.id
  order                   = 10
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_email" {
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_email.recovery_email.id
  order                   = 20
  evaluate_on_plan        = true
  re_evaluate_policies    = true
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_password" {
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_prompt.recovery_password.id
  order                   = 30
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_mfa" {
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_authenticator_validate.mfa.id
  order                   = 40
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_write" {
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_user_write.recovery_write.id
  order                   = 50
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

resource "authentik_flow_stage_binding" "recovery_login" {
  target                  = authentik_flow.recovery.uuid
  stage                   = authentik_stage_user_login.recovery_login.id
  order                   = 100
  evaluate_on_plan        = true
  re_evaluate_policies    = false
  policy_engine_mode      = "any"
  invalid_response_action = "retry"
}

# ── Brand ───────────────────────────────────────────────

resource "authentik_brand" "main" {
  domain              = var.organization_domain
  branding_title      = var.organization_name
  flow_authentication = authentik_flow.authentication.uuid
  flow_recovery       = authentik_flow.recovery.uuid
  default             = true
}
