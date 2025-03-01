resource "adguard_rewrite" "haproxy" {
  for_each = toset([
    "proxmox",
    "opnsense",
    "adguard",
    "unifi",
    "power-panel",
    "valetudo",
    "ceph",
    "ipmi",
  ])
  domain = "${each.value}.nahsi.dev"
  answer = "10.2.1.1"
}

resource "adguard_rewrite" "nfs" {
  domain = "nfs.local"
  answer = "10.2.13.40"
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
