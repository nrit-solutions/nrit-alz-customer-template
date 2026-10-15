# network leaf: the spoke network of this landing zone. Resource group, spoke
# VNet with subnets and an NSG, connected to the connectivity hub. Builds the
# network only, inside the already-placed subscription; the lz-vending leaf owns
# placement. The AVM module owns the schema (main.tf). Terragrunt generates the
# backend and the providers, pinned to this subscription from the hierarchy's
# subscription.hcl. Its own state, so it re-plans without touching placement.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# The hub must exist before the spoke connects to it, and the subscription must
# be placed under its management group before policy applies here (ordering
# only, no output reads). Point the first path at the hub unit you deployed:
# caf-connectivity-hub for hub and spoke, caf-connectivity-vwan for Virtual WAN.
dependencies {
  paths = [
    "../../../../../../platform/connectivity/westeurope/caf-connectivity-hub",
    "../../../_global/lz-vending",
  ]
}
