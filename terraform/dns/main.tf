resource "adguard_rewrite" "haproxy" {
  for_each = toset([
    "proxmox",
    "ceph",
  ])
  domain = "${each.value}.nahsi.dev"
  answer = "10.2.1.1"
}

resource "adguard_rewrite" "npm" {
  for_each = toset([
    "npm",
    "truenas",
    "opnsense",
    "adguard",
    "unifi",
    "ha",
    "power-panel",
    "valetudo",
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

resource "cloudflare_record" "torrents" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "torrent.nahsi.dev"
  content = "37.98.199.189"
  type    = "A"
}

resource "cloudflare_record" "vpn" {
  zone_id = data.cloudflare_zone.nahsi.zone_id
  name    = "vpn.nahsi.dev"
  content = "37.98.199.180"
  type    = "A"
}
