resource "authentik_flow" "authentication" {
  name           = "authentication"
  slug           = var.authentication.slug
  title          = var.authentication.title
  designation    = "authentication"
  authentication = "require_unauthenticated"
}

data "authentik_source" "inbuilt" {
  managed = "goauthentik.io/sources/inbuilt"
}

resource "authentik_stage_identification" "identification" {
  name          = "identification"
  user_fields   = ["username", "email"]
  sources       = [data.authentik_source.inbuilt.uuid]
  recovery_flow = var.recovery.enabled ? authentik_flow.recovery[0].uuid : null
}

resource "authentik_stage_password" "password" {
  name     = "password"
  backends = ["authentik.core.auth.InbuiltBackend"]
}

resource "authentik_stage_user_login" "login" {
  name                     = "login"
  session_duration         = var.session_duration
  terminate_other_sessions = var.terminate_other_sessions
  remember_me_offset       = "seconds=0"
}

resource "authentik_flow_stage_binding" "authentication_identification" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_identification.identification.id
  order  = 10
}

resource "authentik_flow_stage_binding" "authentication_password" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_password.password.id
  order  = 20
}

resource "authentik_flow_stage_binding" "authentication_mfa" {
  target               = authentik_flow.authentication.uuid
  stage                = authentik_stage_authenticator_validate.mfa.id
  order                = 30
  evaluate_on_plan     = false
  re_evaluate_policies = true
  policy_engine_mode   = "all"
}

resource "authentik_flow_stage_binding" "authentication_login" {
  target = authentik_flow.authentication.uuid
  stage  = authentik_stage_user_login.login.id
  order  = 40
}
