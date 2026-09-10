# root.hcl — shared config for the deployable tree. Conventionally at
# live/root.hcl, not the repo root: deployables live under live/, repo meta
# stays outside it.
#
# Every unit includes this, and every unit needs expose = true so it can read
# include.root.locals.*:
#   include "root" { path = find_in_parent_folders("root.hcl"), expose = true }
#
# This is the AZURE variant. An AWS/S3 variant is shown commented-out at the end.

locals {
  # Load the hierarchy vars. tenant.hcl / subscription.hcl / region.hcl are each
  # ancestors of every deployable, so find_in_parent_folders resolves them.
  tenant_vars       = read_terragrunt_config(find_in_parent_folders("tenant.hcl"))
  subscription_vars = read_terragrunt_config(find_in_parent_folders("subscription.hcl"))
  region_vars       = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  tenant_id       = local.tenant_vars.locals.tenant_id
  tenant_root_id  = local.tenant_vars.locals.tenant_root_id
  subscription_id = local.subscription_vars.locals.subscription_id
  location        = local.region_vars.locals.location
  location_short  = local.region_vars.locals.location_short
  environment     = local.region_vars.locals.environment
}

# --- Hierarchy values, generated into every unit ------------------------------
# main.tf reads these as plain Terraform through local.context, with no
# root-level inputs block and no variables.tf in the unit. The alternative is a
# root `inputs` block plus variable declarations per unit; pick ONE mechanism
# per repo and stick to it (the repo's AGENTS.md states which).
#
# Namespaced under one object on purpose. A leaf that defines its own
# local.location still cannot collide with local.context.location.
generate "context" {
  path      = "context.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    locals {
      context = {
        tenant_id       = "${local.tenant_id}"
        tenant_root_id  = "${local.tenant_root_id}"
        subscription_id = "${local.subscription_id}"
        location        = "${local.location}"
        location_short  = "${local.location_short}"
        environment     = "${local.environment}"
      }
    }
  EOF
}

# --- Remote state (azurerm, Entra ID auth — no storage account keys) ----------
# NOTE: pre-create the RG + Storage Account + "tfstate" container (azurerm
# auto-bootstrap is experimental). Identity needs "Storage Blob Data Contributor".
# Backend coords come from the Action variables the bootstrap set and the
# reusable workflow exports; the placeholder fallbacks let the tree generate and
# validate fully offline (init -backend=false) with no Azure access. One shared
# state account can back every subscription — its own sub can differ from the
# per-folder subscription.hcl, so it is read separately here.
remote_state {
  backend  = "azurerm"
  generate = { path = "backend.tf", if_exists = "overwrite_terragrunt" }
  config = {
    resource_group_name  = get_env("BACKEND_AZURE_RESOURCE_GROUP_NAME", "placeholder-rg")
    storage_account_name = get_env("BACKEND_AZURE_STORAGE_ACCOUNT_NAME", "placeholdersa")
    container_name       = get_env("BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME", "tfstate")
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    subscription_id      = get_env("AZURE_SUBSCRIPTION_ID", local.subscription_id)
    tenant_id            = local.tenant_id
    use_azuread_auth     = true
  }
}

# --- Provider (generated into every unit) -------------------------------------
# KEEP THIS BLOCK. Most units declare no provider of their own and depend on it
# entirely; deleting it leaves them with no provider configuration and every
# plan fails.
#
# A unit needing a different provider set (the alz provider, say) declares its
# own generate "provider" AND sets merge_strategy = "deep" on its include:
#
#   include "root" {
#     path           = find_in_parent_folders("root.hcl")
#     expose         = true
#     merge_strategy = "deep"
#   }
#
# The deep merge is not optional. Without it Terragrunt aborts with
#   ERROR  Detected generate blocks with the same name: [provider]
# and generates nothing. Verified on Terragrunt 1.0.7. Note this contradicts the
# HCL blocks doc page, which describes a child block silently overriding the
# parent; trust the observed behavior and keep the attribute.
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
  subscription_id     = "${local.subscription_id}"
  tenant_id           = "${local.tenant_id}"
  storage_use_azuread = true
  use_oidc            = true   # CI: workload identity federation
}
EOF
}

# --- Pin the terraform/tofu binary + version (deterministic across machines) --
# Terragrunt defaults to tofu (since v0.57.12); pin explicitly so the choice is not
# implicit. This estate is Terraform (azurerm), so pin "terraform". Switch to
# "tofu" only for an OpenTofu estate.
terraform_binary              = "terraform"
terraform_version_constraint  = ">= 1.12"
terragrunt_version_constraint = ">= 1.0"

# --- Optional blocks (uncomment per the repo's shape) -------------------------
# Catalog sources, for repos on the catalog shape (`terragrunt catalog` TUI):
# catalog {
#   urls = ["https://github.com/your-org/infrastructure-catalog"]
# }
#
# Root-level inputs, the alternative to the generated context.tf above. Only if
# the repo's units declare matching variables; do not run both mechanisms.
# inputs = {
#   location        = local.location
#   subscription_id = local.subscription_id
# }

# ------------------------------------------------------------------------------
# AWS / S3 variant (swap the two generated blocks above for these):
#
# remote_state {
#   backend  = "s3"
#   generate = { path = "backend.tf", if_exists = "overwrite_terragrunt" }
#   config = {
#     bucket       = "myorg-tfstate-${local.account_vars.locals.account_name}"
#     key          = "${path_relative_to_include()}/terraform.tfstate"
#     region       = local.region_vars.locals.aws_region
#     encrypt      = true
#     use_lockfile = true   # native S3 lock (no DynamoDB table)
#   }
# }
# generate "provider" {
#   path      = "providers.tf"
#   if_exists = "overwrite_terragrunt"
#   contents  = <<EOF
# provider "aws" {
#   region              = "${local.region_vars.locals.aws_region}"
#   allowed_account_ids = ["${local.account_vars.locals.aws_account_id}"]
# }
# EOF
# }
