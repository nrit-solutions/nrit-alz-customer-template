# root.hcl
#
# The root contract every unit includes. It reads the layer files above the
# including unit, then generates three files into that unit at run time:
# context.tf (local.context), backend.tf (azurerm, Entra ID auth) and
# providers.tf (azurerm + azapi + azuread). A unit that needs another provider
# set declares its own generate "provider" and sets merge_strategy = "deep".
#
# Coordinates come from the Action variables the reusable workflows export.
# Every get_env falls back to a placeholder, so the tree generates and validates
# offline with no Azure access.

locals {
  # The only optional layer: an unstamped tree has no customer.hcl yet.
  customer_vars = read_terragrunt_config(find_in_parent_folders("customer.hcl", "customer.hcl"), {
    locals = {
      tenant_root_id          = "00000000-0000-0000-0000-000000000000"
      business_unit           = "platform"
      amba_action_group_email = "alerts@example.com"
    }
  })
  tenant_vars       = read_terragrunt_config(find_in_parent_folders("tenant.hcl"))
  subscription_vars = read_terragrunt_config(find_in_parent_folders("subscription.hcl"))
  region_vars       = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars          = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  tenant_id       = local.tenant_vars.locals.tenant_id
  subscription_id = local.subscription_vars.locals.subscription_id
  location        = local.region_vars.locals.location
  location_short  = local.region_vars.locals.location_short
  environment     = local.env_vars.locals.environment

  # Changing it after the first apply moves the whole hierarchy: a migration, not an edit.
  tenant_root_id          = local.customer_vars.locals.tenant_root_id
  business_unit           = local.customer_vars.locals.business_unit
  amba_action_group_email = local.customer_vars.locals.amba_action_group_email
}

# One object, so a unit's own location local never collides with local.context.location.
generate "context" {
  path      = "context.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    locals {
      context = {
        tenant_id               = ${jsonencode(local.tenant_id)}
        tenant_root_id          = ${jsonencode(local.tenant_root_id)}
        business_unit           = ${jsonencode(local.business_unit)}
        amba_action_group_email = ${jsonencode(local.amba_action_group_email)}
        subscription_id         = ${jsonencode(local.subscription_id)}
        location                = ${jsonencode(local.location)}
        location_short          = ${jsonencode(local.location_short)}
        environment             = ${jsonencode(local.environment)}
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
    # The state account lives in the management subscription, not the unit's deploy subscription.
    subscription_id  = get_env("AZURE_SUBSCRIPTION_ID", local.subscription_id)
    tenant_id        = local.tenant_id
    use_azuread_auth = true
  }
}

generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        azapi = {
          source  = "Azure/azapi"
          version = "~> 2.12"
        }
        azuread = {
          source  = "hashicorp/azuread"
          version = "~> 3.10"
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

    provider "azuread" {
      tenant_id = "${local.tenant_id}"
    }
  EOF
}

terraform_binary              = "terraform"
terraform_version_constraint  = ">= 1.12"
terragrunt_version_constraint = ">= 1.0"
