# AMBA leaf: the AMBA resources (resource group + remediation identity) and the
# AMBA policy on the amba architecture, in one state. The AVM modules own the
# schema (main.tf). Terragrunt generates the backend and the azurerm + azapi +
# alz providers; alz carries platform/alz plus platform/amba. Isolated from the
# base policy leaf, so an AMBA change re-plans only this leaf.

# deep merge so this unit's generate "provider" overrides root's default block.
# Not optional: under the default include, two same-named generate blocks are a
# hard error ("Detected generate blocks with the same name") and nothing is
# generated at all. Verified on terragrunt 1.0.7.
include "root" {
  path           = find_in_parent_folders("root.hcl")
  expose         = true
  merge_strategy = "deep"
}

generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_providers {
        alz = {
          source  = "Azure/alz"
          version = "~> 0.21"
        }
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
      subscription_id                 = "${include.root.locals.subscription_id}"
      tenant_id                       = "${include.root.locals.tenant_id}"
      resource_provider_registrations = "none"
      features {}
    }

    provider "azapi" {
      subscription_id            = "${include.root.locals.subscription_id}"
      tenant_id                  = "${include.root.locals.tenant_id}"
      skip_provider_registration = true
    }

    provider "alz" {
      library_references = [
        { path = "platform/alz", ref = "2026.04.2" },
        { path = "platform/amba", ref = "2026.06.2" },
      ]
    }
  EOF
}

# The management groups (landing-zones leaf) must exist before AMBA overlays
# policy and grants its identity remediation roles (ordering only).
dependencies {
  paths = ["../landing-zones"]
}
