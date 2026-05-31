# Anonymous write to UnifiedPush topics
resource "ntfy_access" "unified_push" {
  username   = "*"
  topic      = "up*"
  permission = "write-only"
}
