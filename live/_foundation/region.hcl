# region.hcl
#
# The foundation's primary region. It is the real home of the central Log
# Analytics workspace and the AMBA resources, and the nominal region for the
# policy managed identities (the management groups and policy themselves are
# global). Adding more regions does not change the foundation; connectivity and
# workloads fan out per region instead. See docs/foundation-structure.md.

locals {
  location       = "westeurope"
  location_short = "weu"
  environment    = "prod"
}
