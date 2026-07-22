# root.hcl
#
# Shared backend, provider defaults, and locals contract for this customer's
# live tree. Every unit includes this:
#   include "root" { path = find_in_parent_folders("root.hcl") ; expose = true }
#
# What lives here:
#   - the remote state backend (Azure Storage, Entra ID auth, no account keys)
#   - the locals every unit reads: tenant, subscription, location
#   - the default provider block: azurerm + azapi, the set most units need.
#     A unit needing a different set (the landing-zones unit uses alz + azapi;
#     the amba unit adds alz) declares its own generate "provider" and sets
#     merge_strategy = "deep" on its include, so its block overrides this one.
#     Without the deep merge, two same-named generate blocks are a hard error.
#
# Coordinates come from the environment the reusable workflows export (the
# AZURE_* and BACKEND_* Action variables the bootstrap set). Each get_env falls
# back to a placeholder so the tree still generates and validates fully offline
# (init -backend=false) with no Azure access.

locals {
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

# The hierarchy values, generated into every unit so main.tf can read them as
# plain Terraform. Namespaced under one object because leaves define their own
# location local; local.context.location never collides with it.
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

remote_state {
  backend = "azurerm"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    resource_group_name  = get_env("BACKEND_AZURE_RESOURCE_GROUP_NAME", "placeholder-rg")
    storage_account_name = get_env("BACKEND_AZURE_STORAGE_ACCOUNT_NAME", "placeholdersa")
    container_name       = get_env("BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME", "tfstate")
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    # The state account lives in the management subscription, which is
    # AZURE_SUBSCRIPTION_ID. A unit's deploy subscription can differ from it
    # (connectivity, for example, deploys to its own subscription but shares
    # this one backend), so the backend subscription is read separately from
    # the per-folder subscription.hcl. Access is by Entra ID, no account keys.
    subscription_id  = get_env("AZURE_SUBSCRIPTION_ID", local.subscription_id)
    tenant_id        = local.tenant_id
    use_azuread_auth = true
  }
}

# Default providers: azurerm + azapi, pinned to the unit's own subscription and
# tenant. The two units that need the alz provider (landing-zones, amba) declare
# their own generate "provider", which shallow-merges over this one.
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        azapi = {
          source  = "Azure/azapi"
          version = "~> 2.4"
        }
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~> 4.0"
        }
      }
    }

    provider "azurerm" {
      subscription_id                 = "${local.subscription_id}"
      tenant_id                       = "${local.tenant_id}"
      resource_provider_registrations = "none"
      features {}
    }

    provider "azapi" {
      subscription_id            = "${local.subscription_id}"
      tenant_id                  = "${local.tenant_id}"
      skip_provider_registration = true
    }
  EOF
}

terraform_binary              = "terraform"
terraform_version_constraint  = ">= 1.12"
terragrunt_version_constraint = ">= 1.0"
