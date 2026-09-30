resource "tls_private_key" "signing" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "signing" {
  private_key_pem       = tls_private_key.signing.private_key_pem
  validity_period_hours = 87600
  early_renewal_hours   = 0
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]

  subject {
    common_name = var.app_name
  }
}

resource "authentik_certificate_key_pair" "signing" {
  name             = "${var.app_name}-signing"
  certificate_data = tls_self_signed_cert.signing.cert_pem
  key_data         = tls_private_key.signing.private_key_pem
}
