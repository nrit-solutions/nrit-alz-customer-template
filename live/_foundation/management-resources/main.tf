locals {
  tags = {
    businessunit    = "changeme"
    env             = local.context.environment
    costcenter      = "platform"
    app             = "alz-platform-foundation"
    opsteam         = "platform-team"
    criticality     = "mission-critical"
    confidentiality = "confidential"
    "managed-by"    = "terraform"
  }
}

module "management_resources" {
  source  = "Azure/avm-ptn-alz-management/azurerm"
  version = "0.9.0"

  automation_account_name                   = null
  location                                  = local.context.location
  resource_group_name                       = "rg-management-${local.context.environment}-${local.context.location_short}"
  log_analytics_workspace_name              = "law-management-${local.context.environment}-${local.context.location_short}"
  log_analytics_workspace_retention_in_days = 30

  data_collection_rules = {
    change_tracking = { name = "dcr-change-tracking-${local.context.environment}-${local.context.location_short}" }
    vm_insights     = { name = "dcr-vm-insights-${local.context.environment}-${local.context.location_short}" }
    defender_sql    = { name = "dcr-defender-sql-${local.context.environment}-${local.context.location_short}" }
  }

  user_assigned_managed_identities = {
    ama = { name = "uami-management-ama-${local.context.environment}-${local.context.location_short}" }
  }

  enable_telemetry = false
  tags             = local.tags
}
