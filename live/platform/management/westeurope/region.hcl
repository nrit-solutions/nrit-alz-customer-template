# region.hcl
#
# Region and environment for management-subscription deployments in this
# region. The platform foundation lives here; location is read by root.hcl
# and exposed to its units.

locals {
  location       = "westeurope"
  location_short = "weu"
  environment    = "prod"
}
