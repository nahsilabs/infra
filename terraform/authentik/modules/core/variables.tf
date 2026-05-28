variable "organization_name" {
  description = "Organization name shown in authentik UI"
  type        = string
}

variable "organization_domain" {
  description = "Domain of the authentik instance"
  type        = string
}

variable "session_duration" {
  description = "Session duration for user logins (format: days=N;hours=N;minutes=N;seconds=N)"
  type        = string
  default     = "days=30"
}

variable "extra_groups" {
  description = "Additional groups to create"
  type        = set(string)
  default     = []
}
