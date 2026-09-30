resource "authentik_stage_authenticator_totp" "totp_setup" {
  name          = "totp-setup"
  digits        = "6"
  friendly_name = "TOTP"
}

resource "authentik_stage_authenticator_validate" "mfa" {
  name                  = "mfa-validate"
  device_classes        = ["totp"]
  not_configured_action = "configure"
  configuration_stages  = [authentik_stage_authenticator_totp.totp_setup.id]
  last_auth_threshold   = "seconds=0"
}
