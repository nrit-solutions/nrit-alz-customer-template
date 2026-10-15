# Connectivity hub leaf, Virtual WAN form: the connectivity resource group, one
# Virtual WAN, one secured virtual hub with a Basic Azure Firewall and its
# policy. The AVM modules own the schema (main.tf). Terragrunt generates the
# backend (from root.hcl) and the providers, and pins the subscription to the
# connectivity subscription from subscription.hcl. Its own state.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# The connectivity management group and its policy must exist before the hub
# resources are created (ordering only, no output reads).
dependencies {
  paths = ["../../../../_foundation/landing-zones"]
}
