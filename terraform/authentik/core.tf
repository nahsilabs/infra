module "core" {
  source = "./modules/core"

  organization_name = "nahsilabs"
  brand = {
    domain = "auth.nahsi.dev"
  }
  authentication = {
    slug  = "nahsilabs-authentication"
    title = "nahsilabs Login"
  }
  session_duration         = "days=30"
  terminate_other_sessions = true
  enrollment_group_id      = authentik_group.users.id
  enrollment = {
    slug                 = "nahsilabs-enrollment"
    title                = "Create your nahsilabs account"
    confirmation_message = "You've been invited to create a NahsiLabs account."
    capture_identity     = true
  }
  passwords = {
    minimum_length         = 16
    hibp_allowed_count     = 1
    check_zxcvbn           = true
    zxcvbn_score_threshold = 2
    length_error_message   = "Password must be at least 16 characters."
  }
  recovery = {
    enabled                  = true
    slug                     = "nahsilabs-recovery"
    activate_user_on_success = true
  }
}
