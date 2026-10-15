# region.hcl
#
# lz-vending only places the subscription: it acts on the subscription and the
# management group, not on a region's resources. root.hcl still reads region.hcl
# from every unit, so this co-located file exists to satisfy that read. The
# spoke network's own region.hcl (../westeurope/region.hcl) governs where
# resources go.

locals {
  location       = "westeurope"
  location_short = "weu"
}
