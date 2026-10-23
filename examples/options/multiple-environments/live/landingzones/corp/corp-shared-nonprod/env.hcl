# env.hcl
#
# Default environment for this subscription folder. It covers _global/, where
# lz-vending runs. Each environment folder under the region overrides it with
# its own env.hcl; the nearest one above a unit wins.

locals {
  environment = "dev"
}
