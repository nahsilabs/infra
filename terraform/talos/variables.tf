variable "cluster_name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "talos_config_version" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "etcd_image" {
  type = string
}

variable "coredns_image" {
  type = string
}

variable "nodes" {
  type = list(object({
    name              = string
    server_ip         = string
    role              = string
    platform          = optional(string, "nocloud")
    config_patches    = list(string)
    extensions        = list(string)
    extra_kernel_args = optional(list(string), [])
  }))
}
