resource "adguard_rewrite" "haproxy" {
  for_each = toset([
    "ceph",
  ])
  domain = "${each.value}.nahsi.dev"
  answer = "10.2.1.1"
}

resource "adguard_rewrite" "npm" {
  for_each = toset([
    "npm",
    "adguard",
    "unifi",
    "ha",
    "power-panel",
    "proxmox",
    "ipmi",
    "scrutiny",
    "rustfs",
  ])
  domain = "${each.value}.nahsi.dev"
  answer = "10.2.1.4"
}

resource "adguard_rewrite" "truenas" {
  for_each = toset([
    "nfs.local",
    "nfs.lan",
    "s3.nahsi.dev",
    "truenas.nahsi.dev",
  ])
  domain = each.key
  answer = "10.2.10.41"
}

resource "cloudflare_record" "vpn" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "vpn.nahsi.dev"
  content = "37.98.199.180"
  type    = "A"
}

resource "adguard_rewrite" "vpn" {
  domain = "vpn.nahsi.dev"
  answer = "10.2.14.180"
}
