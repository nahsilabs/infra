variable "app_name" {
  description = "Application name and slug"
  type        = string
}

variable "authentik_domain" {
  description = "Domain of the authentik instance"
  type        = string
}

variable "launch_url" {
  description = "URL shown in authentik dashboard"
  type        = string
  default     = ""
}

variable "allowed_groups" {
  description = "List of group IDs that can access this app"
  type        = list(string)
  default     = []
}

variable "redirect_uris" {
  description = "OAuth2 redirect URIs"
  type = list(object({
    url           = string
    matching_mode = optional(string, "strict")
  }))
}

variable "ui_group" {
  description = "Dashboard grouping in authentik"
  type        = string
  default     = ""
}

variable "scopes" {
  description = "Additional managed scope mapping IDs to include"
  type        = list(string)
  default     = []
}
