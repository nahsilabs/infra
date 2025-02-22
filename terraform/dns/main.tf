resource "adguard_rewrite" "haproxy" {
  for_each = toset([
    "proxmox",
    "adguard",
    "ceph-dashboard",
    "opnsense",
    "ipmi",
  ])
  domain = "${each.value}.nahsi.dev"
  answer = "10.2.1.1"
}

resource "adguard_rewrite" "nfs" {
  domain = "nfs.local"
  answer = "10.2.13.40"
}
