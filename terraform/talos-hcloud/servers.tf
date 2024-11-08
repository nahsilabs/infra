locals {
  cp = [
    for i in range(3) : format("%s-%d", "cp", i)
  ]
}

resource "hcloud_server" "controlplane" {
  for_each = { for index, name in local.cp : name => index }

  name        = "talos-${each.key}"
  image       = data.hcloud_image.talos-arm.id
  server_type = "cax21"
  location    = "hel1"

  backups = false

  network {
    network_id = hcloud_network.talos.id
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  labels = {
    role = "controlplane"
  }

  placement_group_id = hcloud_placement_group.talos.id
}
