output "groups" {
  description = "Map of structural and application access group names to group IDs"
  value = merge(
    {
      users        = authentik_group.users.id
      applications = authentik_group.applications.id
      operators    = authentik_group.operators.id
      admins       = authentik_group.admins.id
    },
    { for name, group in authentik_group.application : name => group.id },
  )
}

output "authentication_flow_id" {
  value = authentik_flow.authentication.uuid
}
