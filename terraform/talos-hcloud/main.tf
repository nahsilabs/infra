resource "hcloud_network" "talos" {
  name     = "main"
  ip_range = "10.50.0.0/16"
}

resource "hcloud_network_subnet" "talos" {
  network_id   = hcloud_network.talos.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.50.1.0/24"
}

resource "hcloud_placement_group" "talos" {
  name = "main"
  type = "spread"
}

data "hcloud_image" "talos-x86" {
  with_selector     = "os=talos"
  with_architecture = "x86"
  most_recent       = true
}

data "hcloud_image" "talos-arm" {
  with_selector     = "os=talos"
  with_architecture = "arm"
  most_recent       = true
}

resource "tls_private_key" "talos" {
  algorithm = "ED25519"
}
