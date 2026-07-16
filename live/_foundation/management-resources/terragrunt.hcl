# Management resources leaf: Log Analytics, data collection rules, AMA identity.
# The AVM module owns the schema (main.tf). Terragrunt only generates the backend
# (from root.hcl) and the providers, and pins the subscription from the hierarchy.
# Its own state, so a change here does not re-plan the policy or AMBA leaves.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

