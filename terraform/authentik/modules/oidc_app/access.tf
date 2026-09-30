resource "authentik_policy_binding" "access" {
  for_each       = toset(var.allowed_groups)
  target         = authentik_application.this.uuid
  group          = var.groups[each.key]
  order          = index(var.allowed_groups, each.key)
  failure_result = false
}
