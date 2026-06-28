# root.hcl
#
# Shared backend and locals contract for this customer's live tree. Every unit
# includes this and generates its own providers from the exposed locals:
#   include "root" { path = find_in_parent_folders("root.hcl") ; expose = true }
#
# What lives here:
#   - the remote state backend (Azure Storage, Entra ID auth, no account keys)
#   - the locals every unit reads: tenant, subscription, location
# What does NOT live here:
#   - the provider block. The foundation units need different provider sets (the
#     management unit uses azurerm + azapi; the landing-zones unit uses alz +
#     azapi), and Terragrunt does not let a unit override a generate block it
#     inherited from root, so each unit declares its own generate "provider".
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
  environment     = local.region_vars.locals.environment
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

terraform_binary              = "terraform"
terraform_version_constraint  = ">= 1.12"
terragrunt_version_constraint = ">= 1.0"
