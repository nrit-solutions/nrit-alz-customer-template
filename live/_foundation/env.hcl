# env.hcl
#
# Environment for the foundation: one hierarchy, one workspace, one AMBA
# deployment. root.hcl reads the nearest env.hcl above a unit, so a subtree
# that hosts more than one environment adds a folder per environment with its
# own env.hcl.

locals {
  environment = "prod"
}
