# terragrunt.stack.hcl
#
# The platform foundation for this customer: the CAF management group hierarchy
# and policy, plus the management subscription resources (Log Analytics, data
# collection rules, the AMA identity). It wraps the catalog's
# caf-platform-foundation stack at a pinned tag; the values below are the only
# customer-specific inputs.
#
# Deployed once, at tenant-root scope, from this _global folder. The management
# resources land in the subscription named in subscription.hcl.
#
# To upgrade the catalog, bump catalog_ref and open a pull request: the plan
# workflow shows the diff before anything is applied.

locals {
  catalog_url = "git::https://github.com/nrit-solutions/nrit-terragrunt-catalog.git"
  catalog_ref = "v0.3.2"

  # Customer short name and region tag, used in resource names and tags. Set
  # these during onboarding (see ONBOARDING.md, step 2). Keep customer_name
  # short and lowercase: it goes into resource names with length and character
  # limits.
  customer_name  = "customer"
  location_short = "weu"
  environment    = "prod"

  tags = {
    customer     = local.customer_name
    environment  = local.environment
    workload     = "alz-platform-foundation"
    "managed-by" = "terraform"
  }
}

stack "caf_platform_foundation" {
  source = "${local.catalog_url}//stacks/caf-platform-foundation?ref=${local.catalog_ref}"
  path   = "caf-platform-foundation"
  values = {
    # Management resource names. The same names are passed to both catalog units
    # (the management unit creates them; the landing-zones unit computes its
    # policy default values from them), so set them once here.
    management_resource_group_name            = "rg-management-${local.customer_name}-${local.location_short}"
    log_analytics_workspace_name              = "law-management-${local.customer_name}-${local.location_short}"
    ama_user_assigned_managed_identity_name   = "uami-ama-${local.customer_name}-${local.location_short}"
    log_analytics_workspace_retention_in_days = 30

    # ALZ hierarchy and policy come from the public ALZ Library at this ref.
    architecture_name = "alz"
    alz_library_ref   = "2026.04.2"

    # Place subscriptions into management groups. Empty by default so the first
    # apply never moves live subscriptions. Fill in during onboarding, for
    # example:
    #   subscription_placement = {
    #     corp = { subscription_id = "...", management_group_name = "corp" }
    #   }
    subscription_placement = {}

    tags             = local.tags
    enable_telemetry = false
  }
}
