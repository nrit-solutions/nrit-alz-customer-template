locals {
  hub_resource_group_name = "rg-hub-${local.context.location_short}"
  virtual_wan_name        = "vwan-hub-${local.context.location_short}"
  virtual_hub_name        = "vhub-hub-${local.context.location_short}"

  # The virtual hub's own address space. Azure needs at least a /24; /23 leaves
  # room for the hub router to scale.
  virtual_hub_address_prefix = "10.0.0.0/23"

  tags = {
    businessunit    = local.context.business_unit
    env             = local.context.environment
    costcenter      = "platform"
    app             = "alz-connectivity-virtual-wan"
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

# Secured virtual hub: Virtual WAN, one hub in this region, a Basic Azure
# Firewall in the hub with its policy. Spokes connect to the hub through their
# own network unit (vwan_connection_enabled on the landing zone's spoke), not
# from here, so this unit never changes when a landing zone is added. The
# module defaults every optional resource to ON, so each unwanted one is set
# false; virtual_wan_settings does the same for the DDoS plan.
module "vwan" {
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm"
  version = "0.18.0"

  enable_telemetry = false
  tags             = local.tags

  virtual_wan_settings = {
    virtual_wan = {
      name                = local.virtual_wan_name
      location            = local.context.location
      resource_group_name = module.resource_group.name
      type                = "Standard"
      tags                = local.tags
    }
    enabled_resources = {
      ddos_protection_plan = false
    }
  }

  virtual_hubs = {
    primary = {
      is_primary        = true
      location          = local.context.location
      default_parent_id = module.resource_group.resource_id

      hub = {
        name           = local.virtual_hub_name
        address_prefix = local.virtual_hub_address_prefix
        tags           = local.tags
      }

      enabled_resources = {
        firewall                              = true
        firewall_policy                       = true
        bastion                               = false
        virtual_network_gateway_vpn           = false
        virtual_network_gateway_express_route = false
        private_dns_zones                     = false
        private_dns_resolver                  = false
        sidecar_virtual_network               = false
      }

      # A secured hub firewall is AZFW_Hub. Basic is the SMB tier; moving to
      # Standard re-creates the firewall.
      firewall = {
        name     = "afw-hub-${local.context.location_short}"
        sku_name = "AZFW_Hub"
        sku_tier = "Basic"
        tags     = local.tags
      }

      # Rules live in the policy. Start empty: every spoke that sets
      # secure_internet_traffic on its hub connection goes through this
      # firewall, which denies everything until a rule collection allows it.
      firewall_policy = {
        name                     = "afwp-hub-${local.context.location_short}"
        sku                      = "Basic"
        threat_intelligence_mode = "Alert"
      }
    }
  }
}
