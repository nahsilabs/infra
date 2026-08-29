module "core" {
  source = "./modules/core"

  organization_name   = "nahsilabs"
  organization_domain = "auth.nahsi.dev"

  application_groups = toset([
    "access:actual",
    "access:audiobookshelf",
    "access:dawarich",
    "access:matrix",
    "access:miniflux",
    "access:opencloud",
    "access:trek",
  ])
}
