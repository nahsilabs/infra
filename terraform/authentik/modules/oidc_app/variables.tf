variable "app_name" {
  description = "Application name and stable URL slug. Changing it changes the OIDC issuer."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.app_name)) &&
      !contains(["authorize", "token", "device", "userinfo", "introspect", "revoke"], var.app_name)
    )
    error_message = "app_name must be a lowercase hyphenated slug that does not conflict with an OAuth endpoint."
  }
}

variable "authentik_domain" {
  description = "Authentik hostname, optionally with a port, without a scheme or path."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9.-]*(:[0-9]+)?$", var.authentik_domain))
    error_message = "authentik_domain must be a nonempty hostname without a scheme, path, or whitespace."
  }
}

variable "oidc_defaults" {
  description = "Shared provider flow and scope mapping IDs resolved once by the root module."
  type = object({
    authorization_flow      = string
    invalidation_flow       = string
    default_scope_ids       = list(string)
    entitlement_scope_id    = optional(string)
    offline_access_scope_id = optional(string)
  })
  nullable = false
}

variable "launch_url" {
  description = "Application URL shown in the authentik dashboard."
  type        = string
  default     = ""
  nullable    = false
}

variable "ui_group" {
  description = "Application group shown in the authentik dashboard."
  type        = string
  default     = ""
  nullable    = false
}

variable "groups" {
  description = "Group names mapped to authentik group UUIDs. Membership remains outside this module."
  type        = map(string)
  nullable    = false
}

variable "allowed_groups" {
  description = "Ordered, unique group names permitted to access the application. Any listed group grants access."
  type        = list(string)
  nullable    = false

  validation {
    condition = (
      length(var.allowed_groups) > 0 &&
      length(distinct(var.allowed_groups)) == length(var.allowed_groups) &&
      alltrue([for group in var.allowed_groups : contains(keys(var.groups), group)])
    )
    error_message = "allowed_groups must contain at least one group, without duplicates, and every group must exist in groups."
  }
}

variable "redirect_uris" {
  description = "Explicit authorization callback URIs matched strictly, including native-client schemes and loopback URLs."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = (
      length(var.redirect_uris) + length(var.redirect_uris_regex) > 0 &&
      alltrue([for uri in var.redirect_uris : can(regex("^[A-Za-z][A-Za-z0-9+.-]*:[^[:space:]#*]+$", uri))])
    )
    error_message = "At least one strict or regex callback is required. Strict callbacks must have a URI scheme and contain no whitespace, fragments, or wildcards."
  }
}

variable "redirect_uris_regex" {
  description = "Authorization callback patterns matched as regex, for example loopback callbacks with dynamic ports."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for pattern in var.redirect_uris_regex : trimspace(pattern) != ""])
    error_message = "Regex callback patterns must not be empty."
  }
}

variable "client_type" {
  description = "OAuth2 client type. Public clients cannot keep a client secret."
  type        = string
  default     = "confidential"
  nullable    = false

  validation {
    condition     = contains(["confidential", "public"], var.client_type)
    error_message = "client_type must be confidential or public."
  }
}

variable "offline_access" {
  description = "Enable both the offline_access scope mapping and the refresh_token grant."
  type        = bool
  default     = false
  nullable    = false
}

variable "additional_scope_mapping_ids" {
  description = "Additional authentik scope mapping IDs, not OAuth scope names."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for id in var.additional_scope_mapping_ids : trimspace(id) != ""])
    error_message = "Additional scope mapping IDs must not be empty."
  }
}

variable "entitlements" {
  description = "Entitlement names mapped to groups and usernames. Entitlements do not grant application access."
  type = map(object({
    groups = optional(set(string), [])
    users  = optional(set(string), [])
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for name, entitlement in var.entitlements :
      trimspace(name) != "" && length(entitlement.groups) + length(entitlement.users) > 0 &&
      alltrue([for group in entitlement.groups : contains(keys(var.groups), group)]) &&
      alltrue([for user in entitlement.users : trimspace(user) != ""])
    ])
    error_message = "Every entitlement must have a nonempty name and at least one known group or nonempty username."
  }
}
