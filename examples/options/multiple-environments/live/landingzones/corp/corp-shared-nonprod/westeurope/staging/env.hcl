# env.hcl
#
# Environment of every unit under this folder. root.hcl reads the nearest
# env.hcl above a unit, so this overrides the subscription folder's default.

locals {
  environment = "staging"
}
