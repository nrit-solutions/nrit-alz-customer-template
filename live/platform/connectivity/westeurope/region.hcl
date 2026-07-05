# region.hcl
#
# Region and environment for the connectivity hub. The hub is single region;
# location is read by root.hcl and exposed to the units.

locals {
  location       = "westeurope"
  location_short = "weu"
  environment    = "prod"
}
