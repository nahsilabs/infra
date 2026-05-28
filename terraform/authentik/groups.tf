module "core" {
  source = "./modules/core"

  organization_name   = "nahsilabs"
  organization_domain = "auth.nahsi.dev"

  extra_groups = ["users"]
}
