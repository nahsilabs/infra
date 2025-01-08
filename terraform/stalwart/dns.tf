resource "cloudflare_record" "mail" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "mail.nahsi.dev"
  content = hcloud_server.stalwart.ipv4_address
  type    = "A"
}

resource "cloudflare_record" "mx_nahsi" {
  zone_id  = data.cloudflare_zone.nahsi.zone_id
  name     = "nahsi.dev"
  type     = "MX"
  content  = "mail.nahsi.dev."
  priority = 10
}

resource "cloudflare_record" "dkim_ed25519" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "202412e._domainkey.nahsi.dev"
  type    = "TXT"
  content = "v=DKIM1; k=ed25519; h=sha256; p=9BQ77EbvHMGdxMUtqTiQiGvxnrX1ZUy1uotI4JzYElo="
}

resource "cloudflare_record" "dkim_rsa" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "202412r._domainkey.nahsi.dev"
  type    = "TXT"
  content = "v=DKIM1; k=rsa; h=sha256; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtZgSQmKCN1jAzbpOboVnnAy62o+5toF1XSwLZiL4gO2qlG4ZURRHiHPhwGAMI3/8HWnHC/YLFsBzZVbl0441hkwED3I39y5bQQmW6cPqhxpkCLaNAFdJ1YkZMhC0Y5vQITQtvUPo55XJ19jDbaqC0+MG+k6xpiR7UBbs8MD9QSUWX9XOtsjnkifEngPKoxJRqWDvhLyqHbb4l/b1kIhWwKwlRZTXDtT5bDEtknocKLJWWvMvLsRboH4SMEFQ41ZMTpSTU7MWEk8MHE7crfBCceiUROK/jzmiZTGN3XykHM0wepGQ1feNRfdeGgwhnFcqHz5qlDZMP9TIGn6JdNHrnwIDAQAB"
}

resource "cloudflare_record" "spf_mail" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "mail.nahsi.dev"
  type    = "TXT"
  content = "v=spf1 a ra=postmaster -all"
}

resource "cloudflare_record" "spf_root" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "nahsi.dev"
  type    = "TXT"
  content = "v=spf1 mx ra=postmaster -all"
}

resource "cloudflare_record" "srv_jmap" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_jmap._tcp.nahsi.dev"
  type    = "SRV"
  data {
    priority = 0
    weight   = 1
    port     = 443
    target   = "mail.nahsi.dev."
  }
}

resource "cloudflare_record" "srv_imaps" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_imaps._tcp.nahsi.dev"
  type    = "SRV"
  data {
    priority = 0
    weight   = 1
    port     = 993
    target   = "mail.nahsi.dev."
  }
}

resource "cloudflare_record" "srv_submissions" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_submissions._tcp.nahsi.dev"
  type    = "SRV"
  data {
    priority = 0
    weight   = 1
    port     = 465
    target   = "mail.nahsi.dev."
  }
}

resource "cloudflare_record" "cname_autoconfig" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "autoconfig.nahsi.dev"
  type    = "CNAME"
  content = "mail.nahsi.dev."
}

resource "cloudflare_record" "cname_autodiscover" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "autodiscover.nahsi.dev"
  type    = "CNAME"
  content = "mail.nahsi.dev."
}

resource "cloudflare_record" "cname_mta_sts" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "mta-sts.nahsi.dev"
  type    = "CNAME"
  content = "mail.nahsi.dev."
}

resource "cloudflare_record" "txt_mta_sts" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_mta-sts.nahsi.dev"
  type    = "TXT"
  content = "v=STSv1; id=3338579573492679537"
}

resource "cloudflare_record" "dmarc" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_dmarc.nahsi.dev"
  type    = "TXT"
  content = "v=DMARC1; p=reject; rua=mailto:postmaster@nahsi.dev; ruf=mailto:postmaster@nahsi.dev"
}

resource "cloudflare_record" "smtp_tls" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_smtp._tls.nahsi.dev"
  type    = "TXT"
  content = "v=TLSRPTv1; rua=mailto:postmaster@nahsi.dev"
}

locals {
  tlsa_records = [
    { usage = 3, selector = 0, matching_type = 1, certificate_data = "6d732a9cd348ffdb4017bcf1c4678f3140bf082baeb7623dddb6f04b60d84407" },
    { usage = 3, selector = 0, matching_type = 2, certificate_data = "ebce9cc6a2d3abc90cac0a6cc28894fb8000625e5fec59031388f289e26b65ab03074b785a3ac92d38f8ec8e6d3ea8dfa830692b05fc11d120e92f01f8cb32b9" },
    { usage = 3, selector = 1, matching_type = 1, certificate_data = "b103887dafd069398406164242b1ca2a430737b1b200e4fc61f77d120be77be3" },
    { usage = 3, selector = 1, matching_type = 2, certificate_data = "645cfafd233b464f2a4bc385bf0fe763e6e276366b23d4188463f9364846346342163fb045205b6866e8ace3d33c3d8c94bb070f0c7df956b138b89d3dc2b935" },
    { usage = 2, selector = 0, matching_type = 1, certificate_data = "76e9e288aafc0e37f4390cbf946aad997d5c1c901b3ce513d3d8fadbabe2ab85" },
    { usage = 2, selector = 0, matching_type = 2, certificate_data = "afab698cbbbf892ebb555e09175056c1d4630fe7c350f44dcc6e71843d3b290df00d30ab4e356b630c69169d7633788338922fb637cf5b9f7be20a413eeaa518" },
    { usage = 2, selector = 1, matching_type = 1, certificate_data = "d016e1fe311948aca64f2de44ce86c9a51ca041df6103bb52a88eb3f761f57d7" },
    { usage = 2, selector = 1, matching_type = 2, certificate_data = "f8a2b4e23e82a4494e9998fcc4242bef1277656a118beede55ddfadcb82e20c5dc036dcb3b6c48d2ce04e362a9f477c82ad5a557b06b6f33b45ca6662b37c1c9" }
  ]
}


resource "cloudflare_record" "tlsa_mail_nahsi_dev" {
  for_each = { for idx, record in local.tlsa_records : idx => record }

  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_25._tcp.mail.nahsi.dev"
  type    = "TLSA"
  data {
    usage            = each.value.usage
    selector         = each.value.selector
    matching_type    = each.value.matching_type
    certificate = each.value.certificate_data
  }
}

resource "cloudflare_record" "tlsa_nahsi_dev" {
  for_each = { for idx, record in local.tlsa_records : idx => record }

  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "_25._tcp.nahsi.dev"
  type    = "TLSA"
  data {
    usage            = each.value.usage
    selector         = each.value.selector
    matching_type    = each.value.matching_type
    certificate = each.value.certificate_data
  }
}
