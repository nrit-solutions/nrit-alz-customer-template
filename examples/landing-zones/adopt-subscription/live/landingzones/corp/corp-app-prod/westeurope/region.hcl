# region.hcl
#
# Region of this landing zone's network and workloads. A second region is a
# sibling folder with its own region.hcl and network unit.

locals {
  location       = "westeurope"
  location_short = "weu"
}
