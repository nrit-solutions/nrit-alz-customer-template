# region.hcl
#
# The foundation's primary region. It is the real home of the central Log
# Analytics workspace and the AMBA resources, and the nominal region for the
# policy managed identities (the management groups and policy themselves are
# global). Adding more regions does not change the foundation; connectivity and
# workloads fan out per region instead. See docs/foundation-structure.md.

# The region comes from customer.hcl, which the bootstrap writes once.

locals {
  customer_vars = read_terragrunt_config(find_in_parent_folders("customer.hcl"))

  location       = local.customer_vars.locals.location
  location_short = local.customer_vars.locals.location_short
  environment    = "prod"
}
