resource "hcloud_network" "amnezia" {
  name     = "amnezia"
  ip_range = "10.3.0.0/16"
}

resource "hcloud_network_subnet" "amnezia" {
  network_id   = hcloud_network.amnezia.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.3.1.0/24"
}

resource "hcloud_server" "amnezia" {
  name        = "amnezia"
  image       = "ubuntu-24.04"
  server_type = "cax11"
  location    = "hel1"

  backups = false

  network {
    network_id = hcloud_network.amnezia.id
  }

  public_net {
    ipv4_enabled = true
    ipv6_enabled = false
  }
}
