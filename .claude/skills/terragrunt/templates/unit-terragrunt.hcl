# terragrunt.hcl — a single unit. The repo's shape (its AGENTS.md, if present)
# decides which variant applies; do not mix them in one tree.
#
# Plain-TF shape: this file PLUS a main.tf beside it, nothing else unless a
# `dependency` forces an outputs.tf on the producer and a variables.tf on the
# consumer. This file stays thin (include, optional provider override, optional
# ordering) and carries no `terraform { source }`; the module lives in main.tf,
# from the public registry at an exact version:
#
#   module "hub" {
#     source  = "Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm"
#     version = "0.17.1"
#     location         = local.context.location
#     enable_telemetry = false
#   }
#
# Catalog shape: no main.tf; a `terraform { source }` pinned with ?ref= (see C).
#
# Open the file with a one-line header saying what the unit owns, which
# providers it needs, and why it has its own state.

# =============================================================================
# (A) Plain-TF unit, the common case — inherit everything from root
# =============================================================================
# expose = true is required: it publishes include.root.locals.* to this unit.
# root.hcl generates backend.tf, providers.tf (azurerm + azapi) and context.tf
# into the unit, so main.tf reads hierarchy values as local.context.*.
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Ordering only, no value crosses. Paths are relative to this unit and must
# exist, or the run fails with "Found paths in the 'dependencies' block that do
# not exist". Uncomment and set real paths when this unit must apply after
# another one but needs nothing that unit computed.
#
# dependencies {
#   paths = ["../../../../_foundation/landing-zones"]
# }

# =============================================================================
# (B) When the unit needs a different provider set
# =============================================================================
# merge_strategy = "deep" is MANDATORY here. Without it Terragrunt aborts with
#   ERROR  Detected generate blocks with the same name: [provider]
# and generates nothing at all. Verified on Terragrunt 1.0.7.
#
# include "root" {
#   path           = find_in_parent_folders("root.hcl")
#   expose         = true
#   merge_strategy = "deep"
# }
#
# generate "provider" {
#   path      = "providers.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<-EOF
#     terraform {
#       required_providers {
#         alz   = { source = "Azure/alz",   version = "~> 0.21" }
#         azapi = { source = "Azure/azapi", version = "~> 2.4" }
#       }
#     }
#
#     provider "azapi" {
#       subscription_id            = "${include.root.locals.subscription_id}"
#       tenant_id                  = "${include.root.locals.tenant_id}"
#       skip_provider_registration = true
#     }
#
#     provider "alz" {
#       library_references = [
#         { path = "platform/alz", ref = "2026.04.2" },
#         { custom_url = "${get_terragrunt_dir()}/lib" },
#       ]
#     }
#   EOF
# }

# =============================================================================
# (C) Catalog-shape unit — terraform { source } pinned with ?ref=
# =============================================================================
# For repos on the catalog shape only. Pin a tag, never a branch or `main`.
#
# include "root" {
#   path   = find_in_parent_folders("root.hcl")
#   expose = true
# }
#
# terraform {
#   source = "github.com/your-org/infrastructure-catalog//modules/vnet?ref=v1.4.0"
# }
#
# inputs = {
#   name          = "vnet-corp-prod-weu"
#   address_space = ["10.20.0.0/16"]
# }

# =============================================================================
# (D) Reading a value from another unit — LAST RESORT
# =============================================================================
# Work down this list and take the first that fits, before reaching for a
# `dependency`. Detail in the consuming repo's docs/leaf-data-sharing.md.
#
#   1. Convention   — derive the same name in both units, comment both sides
#   2. data source  — look up a live value by its known name
#   3. Key Vault    — for anything secret, plus a data source to read it
#   4. dependency   — only for a computed value with no stable name
#
# A `dependency` costs an output on the producer, a variable on the consumer,
# and it writes the value into the consumer's state. Never pass a secret through
# one: it lands in two state files. Use Key Vault instead.
#
# dependency "apim" {
#   config_path  = "../apim"
#   mock_outputs = { gateway_url = "https://mock" }
#   # Never omit this. Without it a mock can reach apply and deploy wrong values.
#   mock_outputs_allowed_terraform_commands = ["validate", "plan"]
# }
#
# inputs = {
#   apim_gateway_url = dependency.apim.outputs.gateway_url
# }
