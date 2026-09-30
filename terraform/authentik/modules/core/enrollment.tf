resource "authentik_flow" "enrollment" {
  name           = "enrollment"
  slug           = var.enrollment.slug
  title          = var.enrollment.title
  designation    = "enrollment"
  authentication = "require_unauthenticated"
}

resource "authentik_stage_prompt_field" "invitation_confirmation" {
  name          = "invitation-confirmation"
  field_key     = "invitation_confirmation"
  label         = "Invitation"
  type          = "static"
  initial_value = var.enrollment.confirmation_message
  required      = false
  order         = 0
}

resource "authentik_stage_prompt" "invitation_confirmation" {
  name   = "invitation-confirmation"
  fields = [authentik_stage_prompt_field.invitation_confirmation.id]
}

resource "authentik_stage_invitation" "invitation" {
  name                             = "enrollment-invitation"
  continue_flow_without_invitation = false
}

resource "authentik_stage_prompt_field" "enrollment_username" {
  count = var.enrollment.capture_identity ? 1 : 0

  name        = "enrollment-username-field"
  field_key   = "username"
  label       = "Username"
  type        = "username"
  required    = true
  placeholder = "Username"
  order       = 0
}

resource "authentik_stage_prompt_field" "enrollment_name" {
  count = var.enrollment.capture_identity ? 1 : 0

  name        = "enrollment-name-field"
  field_key   = "name"
  label       = "Name"
  type        = "text"
  required    = true
  placeholder = "Name"
  order       = 1
}

resource "authentik_stage_prompt_field" "enrollment_email" {
  count = var.enrollment.capture_identity ? 1 : 0

  name      = "enrollment-email-field"
  field_key = "email"
  label     = "Invited email address"
  type      = "text_read_only"
  order     = 2
}

resource "authentik_policy_expression" "enrollment_email" {
  count = var.enrollment.capture_identity ? 1 : 0

  name       = "enrollment-invited-email"
  expression = <<-EOT
    from django.core.exceptions import ValidationError
    from django.core.validators import validate_email

    email = request.context.get("prompt_data", {}).get("email")
    if not isinstance(email, str) or not email:
        ak_message("The invitation must include an email address. Ask the administrator for a new invitation.")
        return False
    try:
        validate_email(email)
    except ValidationError:
        ak_message("The invitation email address is invalid. Ask the administrator for a new invitation.")
        return False
    return True
  EOT
}

resource "authentik_stage_prompt" "enrollment_identity" {
  count = var.enrollment.capture_identity ? 1 : 0

  name = "enrollment-identity-prompt"
  fields = [
    authentik_stage_prompt_field.enrollment_username[0].id,
    authentik_stage_prompt_field.enrollment_name[0].id,
    authentik_stage_prompt_field.enrollment_email[0].id,
  ]
  validation_policies = [authentik_policy_expression.enrollment_email[0].id]
}

resource "authentik_stage_user_write" "enrollment" {
  name                     = "enrollment-write"
  user_creation_mode       = "always_create"
  user_type                = "internal"
  create_users_as_inactive = false
  create_users_group       = var.enrollment_group_id
}

resource "authentik_flow_stage_binding" "invitation_confirmation" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_prompt.invitation_confirmation.id
  order  = 0
}

resource "authentik_flow_stage_binding" "enrollment_invitation" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_invitation.invitation.id
  order  = 10
}

resource "authentik_flow_stage_binding" "enrollment_identity" {
  count = var.enrollment.capture_identity ? 1 : 0

  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_prompt.enrollment_identity[0].id
  order  = 20
}

resource "authentik_flow_stage_binding" "enrollment_password" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_prompt.enrollment_password.id
  order  = var.enrollment.capture_identity ? 30 : 20
}

resource "authentik_flow_stage_binding" "enrollment_write" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_write.enrollment.id
  order  = var.enrollment.capture_identity ? 40 : 30
}

resource "authentik_flow_stage_binding" "enrollment_totp" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_authenticator_totp.totp_setup.id
  order  = var.enrollment.capture_identity ? 50 : 40
}

resource "authentik_flow_stage_binding" "enrollment_login" {
  target = authentik_flow.enrollment.uuid
  stage  = authentik_stage_user_login.login.id
  order  = 100
}
