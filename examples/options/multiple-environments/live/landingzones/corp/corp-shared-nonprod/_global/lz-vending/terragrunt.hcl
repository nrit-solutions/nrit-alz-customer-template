# lz-vending leaf: subscription placement, naming and the cost ceiling. Adopts
# the existing subscription, sets its display name, places it under the target
# management group, registers the resource providers the workloads need, and
# sets a monthly budget alert. No network (that is the westeurope/network leaf).
# The AVM module owns the schema (main.tf). Terragrunt generates the backend and
# the azurerm + azapi + azuread providers, pinned to this subscription from the
# hierarchy's subscription.hcl. Its own state, independent of the network leaf,
# so either applies without the other.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# The target management group must exist before this leaf attaches the
# subscription to it (ordering only, no output reads).
dependencies {
  paths = ["../../../../../_foundation/landing-zones"]
}
