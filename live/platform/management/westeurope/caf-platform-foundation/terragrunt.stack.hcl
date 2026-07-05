# terragrunt.stack.hcl
#
# The platform foundation for this customer: the CAF management group hierarchy
# and policy, plus the management subscription resources (Log Analytics, data
# collection rules, the AMA identity). It wraps the catalog's
# caf-platform-foundation stack at a pinned tag; the values below are the only
# customer-specific inputs.
#
# Deployed once, at tenant-root scope, from this folder. subscription.hcl and
# region.hcl are inherited from the two ancestor folders above
# (live/platform/management/), not co-located here, so the management
# subscription id and region are set once for the whole management MG.
#
# To upgrade the catalog, bump catalog_ref and open a pull request: the plan
# workflow shows the diff before anything is applied.

locals {
  catalog_url = "git::https://github.com/nrit-solutions/nrit-terragrunt-catalog.git"
  catalog_ref = "v0.6.1"

  subscription_vars = read_terragrunt_config(find_in_parent_folders("subscription.hcl"))
  region_vars       = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  management_subscription_id = local.subscription_vars.locals.subscription_id
  location_short             = local.region_vars.locals.location_short
  environment                = local.region_vars.locals.environment

  # Customer short name, used in tags. Set during onboarding (see
  # ONBOARDING.md, step 2). Keep it short and lowercase: it goes into resource
  # names with length and character limits.
  customer_name = "customer"

  # owner, criticality, and confidentiality below are placeholders: set them
  # per the customer during onboarding. They are mandatory RG tags under the
  # nrit tag governance (see ONBOARDING.md, step 2).
  tags = {
    customer        = local.customer_name
    environment     = local.environment
    "cost-center"   = "platform"
    workload        = "alz-platform-foundation"
    owner           = "platform-team"
    criticality     = "medium"
    confidentiality = "internal"
    "managed-by"    = "terraform"
  }
}

stack "caf_platform_foundation" {
  source = "${local.catalog_url}//stacks/caf-platform-foundation?ref=${local.catalog_ref}"
  path   = "caf-platform-foundation"
  values = {
    # Management resource names. The same names are passed to both catalog units
    # (the management unit creates them; the landing-zones unit computes its
    # policy default values from them), so set them once here.
    management_resource_group_name            = "rg-management-${local.location_short}"
    log_analytics_workspace_name              = "law-management-${local.location_short}"
    ama_user_assigned_managed_identity_name   = "uami-management-ama-${local.location_short}"
    log_analytics_workspace_retention_in_days = 30

    # ALZ hierarchy and policy from the public ALZ Library, layered with the nrit
    # custom library that adds tag governance (Enforce-Tag-Gov denies RGs missing
    # the four mandatory tags). architecture_name = "alz" + custom_library_url = ""
    # falls back to stock ALZ with no tag governance.
    architecture_name  = "nrit"
    custom_library_url = "${local.catalog_url}//library/platform/nrit?ref=${local.catalog_ref}"
    alz_library_ref    = "2026.04.2"

    # Azure Monitor Baseline Alerts (AMBA). On by default. REQUIRED: replace the
    # placeholder with a real address during onboarding (see ONBOARDING.md, step
    # 2); all AMBA alerts route to this action group. The names follow the
    # region-suffixed convention.
    amba_action_group_email                  = "alerts@example.com"
    amba_resource_group_name                 = "rg-amba-${local.location_short}"
    amba_user_assigned_managed_identity_name = "uami-amba-${local.location_short}"

    # Place subscriptions into management groups. Empty by default so the first
    # apply never moves live subscriptions. Fill in during onboarding, for
    # example, to centrally place the connectivity and management subscriptions:
    #   subscription_placement = {
    #     connectivity = {
    #       subscription_id       = "<connectivity-subscription-id>"
    #       management_group_name = "connectivity"
    #     }
    #     management = {
    #       subscription_id       = local.management_subscription_id
    #       management_group_name = "management"
    #     }
    #   }
    subscription_placement = {}

    # Tag governance ships in Audit by default (the catalog initiative's effects
    # default to Audit): it flags resource groups missing the mandatory tags but
    # does not block them. To enforce, once every RG (including the AMBA and cicd
    # bootstrap groups) carries the mandatory tags, set the effects to Deny:
    #   policy_assignments_to_modify = {
    #     alz = {
    #       policy_assignments = {
    #         Enforce-Tag-Gov = {
    #           parameters = {
    #             rgMandatoryTagsEffect = jsonencode({ value = "Deny" })
    #             criticalityEffect     = jsonencode({ value = "Deny" })
    #             confidentialityEffect = jsonencode({ value = "Deny" })
    #             environmentEffect     = jsonencode({ value = "Deny" })
    #           }
    #         }
    #       }
    #     }
    #   }

    # DDoS: the Enable-DDoS-VNET modify policy injects a DDoS plan reference
    # into every VNet the moment it is created. Production: deploy a DDoS
    # protection plan in the connectivity hub and wire it into policy default
    # values (see ONBOARDING.md). Minimal or dev, with no DDoS plan: disable
    # the modify policy so it does not block VNet creation, by uncommenting:
    # policy_assignments_to_modify = {
    #   connectivity = {
    #     policy_assignments = {
    #       Enable-DDoS-VNET = { creation_enabled = false }
    #     }
    #   }
    #   landingzones = {
    #     policy_assignments = {
    #       Enable-DDoS-VNET = { creation_enabled = false }
    #     }
    #   }
    # }

    tags             = local.tags
    enable_telemetry = false
  }
}
