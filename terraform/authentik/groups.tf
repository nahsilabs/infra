locals {
  referenced_groups = toset(flatten([
    for app in values(local.oidc_apps) : concat(
      app.allowed_groups,
      flatten([
        for entitlement in values(lookup(app, "entitlements", {})) :
        lookup(entitlement, "groups", [])
      ]),
    )
  ]))
  application_groups = toset([
    for group in local.referenced_groups : group
    if startswith(group, "access:")
  ])
  groups = merge(
    { for name, group in authentik_group.application : name => group.id },
    {
      users        = authentik_group.users.id
      applications = authentik_group.applications.id
      operators    = authentik_group.operators.id
      admins       = authentik_group.admins.id
    },
  )
}

resource "authentik_group" "users" {
  name = "users"

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "applications" {
  name    = "applications"
  parents = [authentik_group.users.id]

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "application" {
  for_each = local.application_groups

  name    = each.value
  parents = [authentik_group.applications.id]

  lifecycle {
    ignore_changes = [users]

    precondition {
      condition     = contains(keys(local.oidc_apps), trimprefix(each.key, "access:"))
      error_message = "An access:<slug> group must match an application in the OIDC catalog."
    }
  }
}

resource "authentik_group" "operators" {
  name    = "operators"
  parents = [authentik_group.users.id]

  lifecycle {
    ignore_changes = [users]
  }
}

resource "authentik_group" "admins" {
  name         = "admins"
  is_superuser = true
  parents      = [authentik_group.operators.id]

  lifecycle {
    ignore_changes = [users]
  }
}
