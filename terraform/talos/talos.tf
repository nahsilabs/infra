resource "adguard_rewrite" "talos" {
  domain = "talos.nahsi.dev"
  answer = "10.2.1.1"
}

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_config_version

  lifecycle {
    ignore_changes = [talos_version]
  }
}

locals {
  cluster_endpoint = "https://talos.nahsi.dev:6443"
  control_planes   = [for node in var.nodes : node if node.role == "controlplane"]
  workers          = [for node in var.nodes : node if node.role == "worker"]
  etcd_patch = yamlencode({
    cluster = {
      etcd = {
        image = var.etcd_image
      }
    }
  })
  coredns_patch = yamlencode({
    apiVersion = "v1alpha1"
    kind       = "KubeCoreDNSConfig"
    image      = var.coredns_image
  })
  node_patches = {
    for node in var.nodes : node.name => concat(
      node.role == "controlplane" ? [local.etcd_patch, local.coredns_patch] : [],
      [
        yamlencode({
          apiVersion = "v1alpha1"
          kind       = "UnattendedInstallConfig"
          installer = {
            image = data.talos_image_factory_urls.node[node.name].urls.installer_secureboot
          }
        })
      ],
      [for patch in node.config_patches : file(patch)]
    )
  }
}

resource "talos_image_factory_schematic" "node" {
  for_each = { for node in var.nodes : node.name => node }
  schematic = yamlencode({
    customization = {
      extraKernelArgs = each.value.extra_kernel_args
      systemExtensions = {
        officialExtensions = each.value.extensions
      }
    }
  })
}

data "talos_image_factory_urls" "node" {
  for_each      = { for node in var.nodes : node.name => node }
  talos_version = var.talos_version
  schematic_id  = talos_image_factory_schematic.node[each.key].id
  platform      = each.value.platform
  architecture  = "amd64"
}

data "talos_machine_configuration" "control_plane" {
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  talos_version      = var.talos_config_version
  kubernetes_version = var.kubernetes_version
  config_patches     = [local.etcd_patch, local.coredns_patch]
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "worker" {
  for_each           = { for worker in local.workers : worker.name => worker }
  talos_version      = var.talos_config_version
  kubernetes_version = var.kubernetes_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
}

data "talos_machine_configuration" "control_plane_patched" {
  for_each           = { for control_plane in local.control_planes : control_plane.name => control_plane }
  talos_version      = var.talos_config_version
  kubernetes_version = var.kubernetes_version
  cluster_name       = var.cluster_name
  machine_type       = "controlplane"
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = local.node_patches[each.key]
}

data "talos_machine_configuration" "worker_patched" {
  for_each           = { for worker in local.workers : worker.name => worker }
  talos_version      = var.talos_config_version
  kubernetes_version = var.kubernetes_version
  cluster_name       = var.cluster_name
  cluster_endpoint   = local.cluster_endpoint
  machine_type       = "worker"
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = local.node_patches[each.key]
}

resource "talos_machine_configuration_apply" "control_plane" {
  for_each                    = { for control_plane in local.control_planes : control_plane.name => control_plane }
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.control_plane[each.key].machine_configuration
  node                        = each.value.server_ip
  config_patches              = local.node_patches[each.key]
  apply_mode                  = "staged_if_needing_reboot"
}

resource "talos_machine_configuration_apply" "worker" {
  for_each                    = { for worker in local.workers : worker.name => worker }
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker[each.key].machine_configuration
  node                        = each.value.server_ip
  config_patches              = local.node_patches[each.key]
  apply_mode                  = "staged_if_needing_reboot"
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints = [
    for control_plane in local.control_planes : control_plane.server_ip
  ]
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.control_plane]
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoint             = local.control_planes[0].server_ip
  node                 = local.control_planes[0].server_ip
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.control_planes[0].server_ip
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
