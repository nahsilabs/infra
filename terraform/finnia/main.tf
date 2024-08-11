locals {
  dc = "finnia"
}

resource "hcloud_ssh_key" "bootstrap" {
  name       = "bootstrap key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPwRhhu6agRZdhNnqtmcHplo3M9+FdRPOQK4lNkn7NmL"
}

resource "hcloud_network" "main" {
  name     = "main"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "hashistack" {
  network_id   = hcloud_network.main.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_placement_group" "main" {
  name = "main"
  type = "spread"
}
