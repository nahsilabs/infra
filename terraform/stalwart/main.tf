resource "hcloud_network" "stalwart" {
  name     = "stalwart"
  ip_range = "10.4.0.0/16"
}

resource "hcloud_network_subnet" "stalwart" {
  network_id   = hcloud_network.stalwart.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.4.1.0/24"
}

resource "hcloud_server" "stalwart" {
  name        = "stalwart"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"

  backups = false

  network {
    network_id = hcloud_network.stalwart.id
    alias_ips  = []
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
}
