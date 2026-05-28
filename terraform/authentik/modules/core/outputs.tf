output "groups" {
  description = "Map of group name to group ID"
  value = merge(
    { superusers = authentik_group.superusers.id },
    { for g in authentik_group.extra : g.name => g.id },
  )
}

output "authentication_flow_id" {
  value = authentik_flow.authentication.uuid
}
