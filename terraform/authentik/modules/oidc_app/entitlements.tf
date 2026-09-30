locals {
  entitlement_group_bindings = {
    for binding in flatten([
      for name, entitlement in var.entitlements : [
        for group in entitlement.groups : {
          entitlement = name
          group       = group
        }
      ]
    ]) : jsonencode([binding.entitlement, binding.group]) => binding
  }

  entitlement_user_bindings = {
    for binding in flatten([
      for name, entitlement in var.entitlements : [
        for user in entitlement.users : {
          entitlement = name
          user        = user
        }
      ]
    ]) : jsonencode([binding.entitlement, binding.user]) => binding
  }

  entitlement_usernames = toset(flatten([for entitlement in var.entitlements : tolist(entitlement.users)]))
}

resource "authentik_application_entitlement" "this" {
  for_each    = var.entitlements
  name        = each.key
  application = authentik_application.this.uuid
}

data "authentik_user" "entitlement" {
  for_each = local.entitlement_usernames
  username = each.value
}

resource "authentik_policy_binding" "entitlement_group" {
  for_each       = local.entitlement_group_bindings
  target         = authentik_application_entitlement.this[each.value.entitlement].id
  group          = var.groups[each.value.group]
  order          = index(sort(tolist(var.entitlements[each.value.entitlement].groups)), each.value.group)
  failure_result = false
}

resource "authentik_policy_binding" "entitlement_user" {
  for_each       = local.entitlement_user_bindings
  target         = authentik_application_entitlement.this[each.value.entitlement].id
  user           = data.authentik_user.entitlement[each.value.user].pk
  order          = length(var.entitlements[each.value.entitlement].groups) + index(sort(tolist(var.entitlements[each.value.entitlement].users)), each.value.user)
  failure_result = false
}
