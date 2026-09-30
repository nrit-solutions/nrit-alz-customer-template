data "azapi_client_config" "current" {}

locals {

  amba_resource_group_name                 = "rg-amba-${local.context.location_short}"
  amba_user_assigned_managed_identity_name = "uami-amba-${local.context.location_short}"
  amba_action_group_email                  = "alerts@example.com"

  # AMBA's remediation re-creates this RG with the ALZMonitorResourceGroupTags
  # policy parameter, replacing its tag set, so Terraform and the policy must
  # carry the same tags or they overwrite each other on every cycle.
  amba_resource_group_tags = {
    businessunit        = "changeme"
    env                 = local.context.environment
    costcenter          = "platform"
    app                 = "alz-platform-foundation"
    opsteam             = "platform-team"
    criticality         = "mission-critical"
    confidentiality     = "confidential"
    "managed-by"        = "terraform"
    "_deployed_by_amba" = "true"
  }

  # The action group email is an Array policy parameter, so it is wrapped in a
  # list (a scalar passes plan but fails apply with InvalidPolicyParameterType).
  amba_policy_default_values_raw = {
    amba_alz_management_subscription_id          = data.azapi_client_config.current.subscription_id
    amba_alz_resource_group_name                 = local.amba_resource_group_name
    amba_alz_resource_group_location             = local.context.location
    amba_alz_user_assigned_managed_identity_name = local.amba_user_assigned_managed_identity_name
    amba_alz_action_group_email                  = [local.amba_action_group_email]
    amba_alz_resource_group_tags                 = local.amba_resource_group_tags
  }
  amba_policy_default_values = { for key, value in local.amba_policy_default_values_raw : key => jsonencode({ value = value }) }
}

module "amba_resources" {
  source  = "Azure/avm-ptn-monitoring-amba-alz/azurerm"
  version = "0.4.0"

  location                            = local.context.location
  root_management_group_name          = "alz"
  resource_group_name                 = local.amba_resource_group_name
  user_assigned_managed_identity_name = local.amba_user_assigned_managed_identity_name
  enable_telemetry                    = false
  tags                                = local.amba_resource_group_tags
}

module "amba_policy" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.21.0"

  architecture_name  = "amba"
  parent_resource_id = data.azapi_client_config.current.tenant_id
  location           = local.context.location
  enable_telemetry   = false

  policy_default_values = local.amba_policy_default_values

  # The identity must exist before AMBA assigns policies and grants it the
  # remediation roles.
  policy_assignments_dependencies      = [module.amba_resources]
  policy_role_assignments_dependencies = [module.amba_resources]
}
