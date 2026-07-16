data "azapi_client_config" "current" {}

locals {
  location       = "westeurope"
  location_short = "weu"

  amba_resource_group_name                 = "rg-amba-${local.location_short}"
  amba_user_assigned_managed_identity_name = "uami-amba-${local.location_short}"
  amba_action_group_email                  = "alerts@example.com"

  # The action group email is an Array policy parameter, so it is wrapped in a
  # list (a scalar passes plan but fails apply with InvalidPolicyParameterType).
  amba_policy_default_values_raw = {
    amba_alz_management_subscription_id          = data.azapi_client_config.current.subscription_id
    amba_alz_resource_group_name                 = local.amba_resource_group_name
    amba_alz_resource_group_location             = local.location
    amba_alz_user_assigned_managed_identity_name = local.amba_user_assigned_managed_identity_name
    amba_alz_action_group_email                  = [local.amba_action_group_email]
  }
  amba_policy_default_values = { for key, value in local.amba_policy_default_values_raw : key => jsonencode({ value = value }) }
}

module "amba_resources" {
  source  = "Azure/avm-ptn-monitoring-amba-alz/azurerm"
  version = "0.4.0"

  location                            = local.location
  root_management_group_name          = "alz"
  resource_group_name                 = local.amba_resource_group_name
  user_assigned_managed_identity_name = local.amba_user_assigned_managed_identity_name
  enable_telemetry                    = false
  # No tags: AMBA policy remediation redeploys this RG and stamps _deployed_by_amba, stripping any tags Terraform sets, so managing them here drifts every cycle. Leave the RG AMBA-owned (azapi leaves a null tags attribute unmanaged).
}

module "amba_policy" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.21.0"

  architecture_name  = "amba"
  parent_resource_id = data.azapi_client_config.current.tenant_id
  location           = local.location
  enable_telemetry   = false

  policy_default_values = local.amba_policy_default_values

  # The identity must exist before AMBA assigns policies and grants it the
  # remediation roles.
  policy_assignments_dependencies      = [module.amba_resources]
  policy_role_assignments_dependencies = [module.amba_resources]
}
