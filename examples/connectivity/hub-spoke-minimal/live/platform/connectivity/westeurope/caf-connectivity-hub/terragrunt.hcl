# Connectivity hub leaf: the hub resource group and one hub virtual network. The
# AVM modules own the schema (main.tf). Terragrunt generates the backend (from
# root.hcl) and the providers, and pins the subscription to the connectivity
# subscription from subscription.hcl (a different subscription from the
# management sub that holds the shared state backend). Its own state.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# The connectivity management group and its policy must exist before this hub
# VNet is created, otherwise Enable-DDoS-VNET would deny it once enabled
# (ordering only, no output reads).
dependencies {
  paths = ["../../../../_foundation/landing-zones"]
}
