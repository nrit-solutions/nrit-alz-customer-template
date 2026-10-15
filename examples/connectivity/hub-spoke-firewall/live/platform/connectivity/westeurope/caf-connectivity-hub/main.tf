locals {
  hub_resource_group_name  = "rg-hub-${local.context.location_short}"
  hub_virtual_network_name = "vnet-hub-${local.context.location_short}"
  hub_address_space        = "10.0.0.0/16"

  # Azure Firewall needs two dedicated subnets. The Basic SKU requires the
  # management subnet; both are /26 by Azure's rule.
  firewall_subnet_address_prefix            = "10.0.0.0/26"
  firewall_management_subnet_address_prefix = "10.0.0.64/26"

  tags = {
    businessunit    = local.context.business_unit
    env             = local.context.environment
    costcenter      = "platform"
    app             = "alz-connectivity-hub-and-spoke"
    opsteam         = "platform-team"
    criticality     = "mission-critical"
    confidentiality = "confidential"
    "managed-by"    = "terraform"
  }
}

module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.4.0"

  name             = local.hub_resource_group_name
  location         = local.context.location
  enable_telemetry = false
  tags             = local.tags
}

# Hub with Azure Firewall: the hub virtual network, a Basic firewall with its
# policy, the route table that sends spoke traffic through it, and central
# private link DNS. Bastion, both gateways, the resolver, the DNS security
# policy and the NAT gateway stay off until a workload needs them; the module
# defaults them to ON, so each is set false explicitly.
module "hub_vnet" {
  source  = "Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm"
  version = "0.17.7"

  enable_telemetry = false
  tags             = local.tags

  hub_virtual_networks = {
    primary = {
      location                  = local.context.location
      default_hub_address_space = local.hub_address_space
      default_parent_id         = module.resource_group.resource_id
      hub_virtual_network = {
        name          = local.hub_virtual_network_name
        address_space = [local.hub_address_space]
      }
      enabled_resources = {
        firewall                              = true
        firewall_policy                       = true
        bastion                               = false
        virtual_network_gateway_vpn           = false
        virtual_network_gateway_express_route = false
        private_dns_zones                     = true
        private_dns_resolver                  = false
        dns_resolver_policy                   = false
        nat_gateway                           = false
      }

      # Basic is the SMB tier: no availability zones, no threat intelligence
      # in Deny mode, no TLS inspection. Move to Standard when the workloads
      # need those, which is a re-create of the firewall.
      firewall = {
        name                             = "afw-hub-${local.context.location_short}"
        sku_tier                         = "Basic"
        zones                            = []
        subnet_address_prefix            = local.firewall_subnet_address_prefix
        management_subnet_address_prefix = local.firewall_management_subnet_address_prefix
        tags                             = local.tags
      }

      # Rules live in the policy. Start empty: the firewall denies everything
      # until a rule collection group allows it, and the first workload PR adds
      # the rules it needs next to its own units.
      firewall_policy = {
        name                     = "afwp-hub-${local.context.location_short}"
        sku                      = "Basic"
        threat_intelligence_mode = "Alert"
        dns = {
          proxy_enabled = true
        }
      }

      # Private link DNS is centralised in connectivity, per CAF: the zones live
      # in the hub resource group and every spoke links to them, so a workload
      # unit only references a zone id and never owns one. The foundation's
      # policy default values must name the same zones, see the scenario page.
      private_dns_zones = {
        # The module ships the full Azure private link catalogue, about ninety
        # zones. Start with what the tenant resolves today and add a key when a
        # workload adds a private endpoint of a new type.
        private_link_private_dns_zones = {
          azure_app_service   = { zone_name = "privatelink.azurewebsites.net" }
          azure_key_vault     = { zone_name = "privatelink.vaultcore.azure.net" }
          azure_sql_server    = { zone_name = "privatelink.database.windows.net" }
          azure_storage_blob  = { zone_name = "privatelink.blob.core.windows.net" }
          azure_storage_queue = { zone_name = "privatelink.queue.core.windows.net" }
        }

        # Nothing registers VM hostnames here, and the zone costs the same as a
        # used one.
        auto_registration_zone_enabled = false

        # The hub network is linked by default. Add every spoke that must
        # resolve private endpoints, by the resource id its network unit
        # derives (see the landing zone scenarios).
        virtual_network_link_additional_virtual_networks = {}
      }
    }
  }

  hub_and_spoke_networks_settings = {
    enabled_resources = {
      ddos_protection_plan = false
    }
  }
}
