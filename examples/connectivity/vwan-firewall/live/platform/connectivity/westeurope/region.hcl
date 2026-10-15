# region.hcl
#
# Region of this hub. One hub per region: add a sibling region folder with its
# own region.hcl and hub unit for a second region.

locals {
  location       = "westeurope"
  location_short = "weu"
}
