variable "cluster_name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "nodes" {
  type = list(object({
    name           = string
    server_ip      = string
    role           = string
    config_patches = list(string)
    extensions     = list(string)
  }))
}

variable "flux_variables" {
  type    = map(string)
  default = {}
}
