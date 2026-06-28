# region.hcl
#
# Region and environment for the foundation deployment. The foundation builds
# the tenant-wide management group hierarchy and the management resources, which
# live in one region. location is read by root.hcl and exposed to the units.

locals {
  location       = "westeurope"
  location_short = "weu"
  environment    = "prod"
}
