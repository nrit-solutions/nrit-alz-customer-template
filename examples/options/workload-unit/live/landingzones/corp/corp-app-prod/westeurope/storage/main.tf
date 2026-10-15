locals {
  purpose = "app"

  # The spoke subnet the private endpoint joins, derived from the network
  # unit's names so nothing is read from its state. Change both together.
  network_resource_group_name = "rg-${local.purpose}-network-${local.context.environment}-${local.context.location_short}"
  spoke_virtual_network_name  = "vnet-${local.purpose}-${local.context.environment}-${local.context.location_short}"
  workload_subnet_name        = "snet-${local.purpose}-workload-${local.context.environment}-${local.context.location_short}"
  workload_subnet_id          = "/subscriptions/${local.context.subscription_id}/resourceGroups/${local.network_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${local.spoke_virtual_network_name}/subnets/${local.workload_subnet_name}"

  # The blob private DNS zone lives in the connectivity hub (central private
  # link DNS). Not an ancestor of this folder, so the subscription is a literal.
  connectivity_subscription_id = "00000000-0000-0000-0000-000000000000"
  blob_private_dns_zone_id     = "/subscriptions/${local.connectivity_subscription_id}/resourceGroups/rg-hub-${local.context.location_short}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"

  tags = {
    businessunit    = local.context.business_unit
    env             = local.context.environment
    costcenter      = local.purpose
    app             = "${local.purpose}-storage"
    opsteam         = "platform-team"
    criticality     = "medium"
    confidentiality = "confidential"
    "managed-by"    = "terraform"
  }
}

# Storage account names take no hyphens and cap at 24 characters, so the name is
# generated: st<purpose><env><loc><random>.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.4"

  suffix = [local.purpose, local.context.environment, local.context.location_short]
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name             = "rg-${local.purpose}-storage-${local.context.environment}-${local.context.location_short}"
  location         = local.context.location
  enable_telemetry = false
  tags             = local.tags
}

# Private by construction: no public endpoint, no shared keys, blob reachable
# only over the private endpoint in the spoke, resolved through the hub zone.
module "storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "0.10.0"

  name             = module.naming.storage_account.name_unique
  location         = local.context.location
  parent_id        = module.resource_group.resource_id
  enable_telemetry = false
  tags             = local.tags

  account_kind     = "StorageV2"
  account_sku_name = "Standard_ZRS"

  public_network_access_enabled = false
  shared_access_key_enabled     = false

  network_rules = {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  private_endpoints = {
    blob = {
      name                          = "pep-${module.naming.storage_account.name_unique}-blob"
      subnet_resource_id            = local.workload_subnet_id
      subresource_name              = "blob"
      private_dns_zone_resource_ids = [local.blob_private_dns_zone_id]
      tags                          = local.tags
    }
  }
}
