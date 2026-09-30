variable "organization_name" {
  type = string
}

variable "brand" {
  type = object({
    domain = string
  })
}

variable "authentication" {
  type = object({
    slug  = string
    title = string
  })
}

variable "session_duration" {
  type    = string
  default = "days=30"
}

variable "terminate_other_sessions" {
  type = bool
}

variable "enrollment_group_id" {
  type = string
}

variable "enrollment" {
  type = object({
    slug                 = string
    title                = string
    confirmation_message = string
    capture_identity     = bool
  })
}

variable "passwords" {
  type = object({
    minimum_length         = number
    hibp_allowed_count     = number
    check_zxcvbn           = bool
    zxcvbn_score_threshold = number
    length_error_message   = string
  })
}

variable "recovery" {
  type = object({
    enabled                  = bool
    slug                     = string
    activate_user_on_success = bool
  })
}
