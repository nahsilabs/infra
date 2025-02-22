resource "local_sensitive_file" "kubeconfig" {
  content         = talos_cluster_kubeconfig.this.kubeconfig_raw
  filename        = "${path.root}/kubeconfig"
  file_permission = "0600"
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = "${path.root}/talosconfig"
  file_permission = "0600"
}

output "kubeconfig" {
  value = {
    path    = local_sensitive_file.kubeconfig.filename
    content = local_sensitive_file.kubeconfig.content
  }
  sensitive = true
}

output "talosconfig" {
  value = {
    path    = local_sensitive_file.talosconfig.filename
    content = local_sensitive_file.talosconfig.content
  }
  sensitive = true
}
