resource "authentik_blueprint" "default_authentication" {
  name    = "Default - Authentication flow"
  path    = "default/flow-default-authentication-flow.yaml"
  enabled = false
}

resource "authentik_blueprint" "default_password_change" {
  name    = "Default - Password change flow"
  path    = "default/flow-password-change.yaml"
  enabled = false
}

data "authentik_flow" "default_authentication" {
  slug = "default-authentication-flow"
}

resource "authentik_policy_expression" "deny_default_authentication" {
  name       = "deny-default-authentication"
  expression = "return False"
}

resource "authentik_policy_binding" "deny_default_authentication" {
  target         = data.authentik_flow.default_authentication.id
  policy         = authentik_policy_expression.deny_default_authentication.id
  order          = 0
  failure_result = false

  depends_on = [
    authentik_blueprint.default_authentication,
    authentik_brand.main,
  ]
}
