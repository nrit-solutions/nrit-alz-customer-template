locals {
  # Region matches the region.hcl above this folder. Hardcoded because this leaf
  # takes no variables; the folder is region-specific.
  location       = "westeurope"
  location_short = "weu"

  tags = {
    customer        = "changeme"
    environment     = "prod"
    "cost-center"   = "platform"
    workload        = "alz-platform-foundation"
    owner           = "platform-team"
    criticality     = "mission-critical"
    confidentiality = "internal"
    "managed-by"    = "terraform"
  }
}

module "management_resources" {
  source  = "Azure/avm-ptn-alz-management/azurerm"
  version = "0.9.0"

  automation_account_name                   = null
  location                                  = local.location
  resource_group_name                       = "rg-management-${local.location_short}"
  log_analytics_workspace_name              = "law-management-${local.location_short}"
  log_analytics_workspace_retention_in_days = 30

  data_collection_rules = {
    change_tracking = { name = "dcr-change-tracking-${local.location_short}" }
    vm_insights     = { name = "dcr-vm-insights-${local.location_short}" }
    defender_sql    = { name = "dcr-defender-sql-${local.location_short}" }
  }

  user_assigned_managed_identities = {
    ama = { name = "uami-management-ama-${local.location_short}" }
  }

  enable_telemetry = false
  tags             = local.tags
}
