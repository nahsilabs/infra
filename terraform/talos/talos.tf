resource "adguard_rewrite" "talos" {
  domain = "talos.nahsi.dev"
  answer = "10.2.1.1"
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

locals {
  cluster_endpoint = "https://talos.nahsi.dev:6443"
}

data "talos_machine_configuration" "control_plane" {
  for_each         = { for control_plane in var.control_planes : control_plane.name => control_plane }
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = local.cluster_endpoint
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "worker" {
  for_each         = { for worker in var.workers : worker.name => worker }
  talos_version    = var.talos_version
  cluster_name     = var.cluster_name
  cluster_endpoint = local.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each                    = { for control_plane in var.control_planes : control_plane.name => control_plane }
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  node                        = each.value.server_ip
  config_patches              = [for patch in each.value.config_patches : file(patch)]
}

resource "talos_machine_configuration_apply" "worker" {
  for_each                    = { for worker in var.workers : worker.name => worker }
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.server_ip
  config_patches              = [for patch in each.value.config_patches : file(patch)]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    for control_plane in var.control_planes : control_plane.server_ip
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.control_plane]
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = var.control_planes[0].server_ip
  node                 = var.control_planes[0].server_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = var.control_planes[0].server_ip
  endpoint             = local.cluster_endpoint
  timeouts = {
    create = "3m"
  }
}

data "http" "talos_health" {
  url      = "${local.cluster_endpoint}/version"
  insecure = true
  retry {
    attempts     = 60
    min_delay_ms = 5000
    max_delay_ms = 5000
  }
  depends_on = [talos_machine_bootstrap.this]
}
