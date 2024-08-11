locals {
  server = [
    for i in range(3) : format("%s-%d", "server", i)
  ]
}

resource "hcloud_server" "server" {
  for_each = { for index, name in local.server : name => index }

  depends_on = [
    hcloud_network_subnet.hashistack
  ]

  name        = "${local.dc}-${each.key}"
  image       = "ubuntu-24.04"
  server_type = "cax21"
  location    = "hel1"

  ssh_keys = [
    hcloud_ssh_key.bootstrap.name
  ]

  backups = false

  network {
    network_id = hcloud_network.main.id
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }

  labels = {
    type = "server"
    dc   = local.dc
  }

  placement_group_id = hcloud_placement_group.main.id
}

resource "cloudflare_record" "server" {
  for_each = { for index, name in local.server : name => index }

  zone_id = data.cloudflare_zone.nahsi_dev.zone_id
  name    = "${each.key}.${local.dc}.nahsi.dev"
  value   = hcloud_server.server[each.key].ipv4_address
  type    = "A"
}

resource "cloudflare_record" "internal" {
  for_each = { for index, name in local.server : name => index }

  zone_id = data.cloudflare_zone.nahsi_dev.zone_id
  name    = "servers.${local.dc}.nahsi.dev"
  value   = flatten([for net in hcloud_server.server[each.key].network : net.ip])[0]
  type    = "A"
}
