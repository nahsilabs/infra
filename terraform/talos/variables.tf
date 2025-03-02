variable "cluster_name" {
  type = string
}

variable "talos_version" {
  type = string
}

variable "control_planes" {
  type = list(object({
    name           = string
    server_ip      = string
    config_patches = list(string)
  }))
}

variable "workers" {
  type = list(object({
    name           = string
    server_ip      = string
    config_patches = list(string)
  }))
  default = []
}

variable "flux_variables" {
  type    = map(string)
  default = {}
}
