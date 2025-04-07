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
    "truenas",
    "adguard",
    "unifi",
    "ha",
    "power-panel",
    "valetudo",
    "proxmox",
    "ipmi",
  ])
  domain = "${each.value}.nahsi.dev"
  answer = "10.2.1.4"
}

resource "adguard_rewrite" "nfs" {
  domain = "nfs.local"
  answer = "10.2.10.41"
}

resource "adguard_rewrite" "nfs-lan" {
  domain = "nfs.lan"
  answer = "10.2.10.41"
}

resource "cloudflare_record" "seedbox-0" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "torrent.nahsi.dev"
  content = "37.98.199.179"
  type    = "A"
}

resource "adguard_rewrite" "seedbox-0" {
  domain = "torrent.nahsi.dev"
  answer = "10.2.14.179"
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
