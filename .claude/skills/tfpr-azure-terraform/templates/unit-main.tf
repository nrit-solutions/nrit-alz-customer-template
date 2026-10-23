locals {
  purpose = "<purpose>"

  # Landing zone order. Under _foundation/ and platform/, drop the environment.
  name_suffix = "${local.purpose}-${local.context.environment}-${local.context.location_short}"

  tags = {
    businessunit    = local.context.business_unit
    env             = local.context.environment
    costcenter      = local.purpose
    app             = "${local.purpose}-<component>"
    opsteam         = "platform-team"
    criticality     = "medium"
    confidentiality = "confidential"
    "managed-by"    = "terraform"
  }
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name             = "rg-${local.name_suffix}"
  location         = local.context.location
  enable_telemetry = false
  tags             = local.tags
}

module "<component>" {
  source  = "Azure/avm-res-<provider>-<type>/azurerm"
  version = "<exact version from the registry>"

  name             = "<abbreviation>-${local.name_suffix}"
  location         = local.context.location
  parent_id        = module.resource_group.resource_id
  enable_telemetry = false
  tags             = local.tags
}
