# storage leaf: one storage account for the app landing zone, in its own
# resource group. A workload unit next to the network unit: its own state, so
# it plans and applies without touching the spoke. The AVM module owns the
# schema (main.tf). Terragrunt generates the backend and the providers, pinned
# to this subscription from the hierarchy's subscription.hcl.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# The spoke must exist first: the private endpoint lands in its subnet
# (ordering only, no output reads; the subnet id is derived by convention).
dependencies {
  paths = ["../network"]
}
