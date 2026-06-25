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
  description = "List of group names that can access this app"
  type        = list(string)
  default     = []
}

variable "groups" {
  description = "Group name -> ID map, used to resolve allowed_groups and entitlement groups"
  type        = map(string)
  default     = {}
}

variable "redirect_uris" {
  description = "OAuth2 redirect URIs"
  type        = list(string)
}

variable "ui_group" {
  description = "Dashboard grouping in authentik"
  type        = string
  default     = ""
}

variable "logout_uri" {
  description = "URI to redirect to after logout"
  type        = string
  default     = ""
}

variable "scopes" {
  description = "Additional managed scope mapping IDs to include"
  type        = list(string)
  default     = []
}

variable "client_type" {
  description = "OAuth2 client type. Use 'public' for PKCE clients that cannot hold a secret (native/MCP)."
  type        = string
  default     = "confidential"
  validation {
    condition     = contains(["confidential", "public"], var.client_type)
    error_message = "client_type must be 'confidential' or 'public'."
  }
}

variable "entitlements" {
  description = "Application entitlements: name -> { groups = [group names], users = [usernames] }"
  type = map(object({
    groups = optional(list(string), [])
    users  = optional(list(string), [])
  }))
  default = {}
}
