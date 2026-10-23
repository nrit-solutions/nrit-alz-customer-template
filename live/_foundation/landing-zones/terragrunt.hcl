# Landing zones leaf: management groups, policy, subscription placement on the
# base architecture. The AVM module owns the schema (main.tf). Terragrunt
# generates the backend and the azapi + alz providers; alz carries platform/alz
# plus the custom policy library, vendored locally under lib/. Its own state.

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
      }
    }

    provider "azapi" {
      subscription_id            = "${include.root.locals.subscription_id}"
      tenant_id                  = "${include.root.locals.tenant_id}"
      skip_provider_registration = true
    }

    provider "alz" {
      library_overwrite_enabled = true
      library_references = [
        { path = "platform/alz", ref = "2026.04.2" },
        { custom_url = "${get_terragrunt_dir()}/lib" },
      ]
    }
  EOF
}

# Management resources must exist before the policy role assignments that
# reference them (ordering only, no output reads).
dependencies {
  paths = ["../management-resources"]
}
