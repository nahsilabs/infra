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

resource "authentik_stage_prompt_field" "password_repeat" {
  field_key   = "password_repeat"
  label       = "Confirm password"
  name        = "password-repeat-field"
  type        = "password"
  placeholder = "Repeat password"
  required    = true
  order       = 1
}

locals {
  password_fields = [
    authentik_stage_prompt_field.password.id,
    authentik_stage_prompt_field.password_repeat.id,
  ]
  password_policies = sort(concat(
    [authentik_policy_password.length.id, authentik_policy_password.pwned.id],
    authentik_policy_password.complexity[*].id,
  ))
}

resource "authentik_stage_prompt" "enrollment_password" {
  name                = "recovery-password-prompt"
  fields              = local.password_fields
  validation_policies = local.password_policies
}

resource "authentik_stage_prompt" "default_password_change" {
  name                = "default-password-change-prompt"
  fields              = local.password_fields
  validation_policies = local.password_policies

  depends_on = [authentik_blueprint.default_password_change]
}

resource "authentik_policy_password" "length" {
  name                    = "password-min-length"
  length_min              = var.passwords.minimum_length
  amount_digits           = 0
  amount_lowercase        = 0
  amount_uppercase        = 0
  amount_symbols          = 0
  check_static_rules      = true
  check_have_i_been_pwned = false
  check_zxcvbn            = false
  error_message           = var.passwords.length_error_message
}

resource "authentik_policy_password" "pwned" {
  name                    = "password-pwned"
  check_have_i_been_pwned = true
  hibp_allowed_count      = var.passwords.hibp_allowed_count
  error_message           = "Password is in a known breach database."
}

resource "authentik_policy_password" "complexity" {
  count = var.passwords.check_zxcvbn ? 1 : 0

  name                   = "password-complexity"
  check_zxcvbn           = true
  zxcvbn_score_threshold = var.passwords.zxcvbn_score_threshold
  error_message          = "Password is not strong enough."
}
