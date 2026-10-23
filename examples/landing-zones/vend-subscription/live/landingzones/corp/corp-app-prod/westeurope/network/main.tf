data "azapi_client_config" "current" {}

locals {
  purpose = "app"

  # The connectivity hub this spoke connects to. Derived from the connectivity
  # subscription, resource group and hub name the hub unit uses, so it is known
  # at plan time and needs no output read. The connectivity subscription is not
  # an ancestor of this folder, so its id is a literal: replace it.
  connectivity_subscription_id = "00000000-0000-0000-0000-000000000000"
  hub_resource_group_name      = "rg-hub-${local.context.location_short}"

  # Hub and spoke: the hub virtual network, peered. With Virtual WAN, comment
  # these two lines out and uncomment the virtual hub pair below; tflint fails
  # on a declared local that nothing uses.
  hub_virtual_network_name = "vnet-hub-${local.context.location_short}"
  hub_virtual_network_id   = "/subscriptions/${local.connectivity_subscription_id}/resourceGroups/${local.hub_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${local.hub_virtual_network_name}"

  # Virtual WAN instead: the virtual hub this spoke connects to. Uncomment with
  # the vWAN block below.
  # virtual_hub_name = "vhub-hub-${local.context.location_short}"
  # virtual_hub_id   = "/subscriptions/${local.connectivity_subscription_id}/resourceGroups/${local.hub_resource_group_name}/providers/Microsoft.Network/virtualHubs/${local.virtual_hub_name}"

  # With an Azure Firewall in a hub and spoke hub, spoke traffic reaches it over
  # a route table. The firewall takes the first usable address of its subnet,
  # so the next hop is known at plan time from the hub's address plan.
  firewall_private_ip = "10.0.0.4"

  tags = {
    businessunit    = local.context.business_unit
    env             = local.context.environment
    costcenter      = local.purpose
    app             = "lz-network-${local.purpose}"
    opsteam         = "platform-team"
    criticality     = "medium"
    confidentiality = "confidential"
    "managed-by"    = "terraform"
  }
}

module "network" {
  source  = "Azure/avm-ptn-alz-sub-vending/azure"
  version = "0.3.4"

  location         = local.context.location
  enable_telemetry = false

  # Network only: the subscription is placed by the lz-vending leaf. Every
  # subscription-level input is fixed off so the two never contend for the
  # subscription-level state.
  subscription_alias_enabled                        = false
  subscription_id                                   = data.azapi_client_config.current.subscription_id
  subscription_update_existing                      = false
  subscription_tags                                 = {}
  subscription_management_group_association_enabled = false
  subscription_management_group_id                  = null

  resource_group_creation_enabled = true
  virtual_network_enabled         = true
  network_security_group_enabled  = true

  # Hub and spoke with Azure Firewall: route every subnet through the firewall.
  # Leave false on the minimal hub and on Virtual WAN (routing intent does it).
  route_table_enabled = false

  resource_groups = {
    network = {
      name     = "rg-${local.purpose}-network-${local.context.environment}-${local.context.location_short}"
      location = local.context.location
      tags     = local.tags
    }
  }

  # The ALZ landing-zone policy Deny-Subnet-Without-Nsg denies any subnet with
  # no network security group, so create one and associate every subnet.
  network_security_groups = {
    workload = {
      name               = "nsg-${local.purpose}-workload-${local.context.environment}-${local.context.location_short}"
      location           = local.context.location
      resource_group_key = "network"
      tags               = local.tags
    }
  }

  route_tables = {
    to_firewall = {
      name               = "rt-${local.purpose}-${local.context.environment}-${local.context.location_short}"
      location           = local.context.location
      resource_group_key = "network"
      tags               = local.tags
      routes = {
        default = {
          name                   = "default-via-firewall"
          address_prefix         = "0.0.0.0/0"
          next_hop_type          = "VirtualAppliance"
          next_hop_in_ip_address = local.firewall_private_ip
        }
      }
    }
  }

  virtual_networks = {
    spoke = {
      name               = "vnet-${local.purpose}-${local.context.environment}-${local.context.location_short}"
      resource_group_key = "network"
      address_space      = ["10.16.0.0/24"]

      # Set explicitly so the config matches what the ALZ inherit-tag policy
      # copies onto the VNet from the resource group; without this it drifts on
      # every plan.
      tags = local.tags

      # Hub and spoke: peer to the hub virtual network. The minimal and the
      # firewall hubs have no VPN or ExpressRoute gateway, so the spoke must not
      # request remote gateways (the module default is true).
      hub_network_resource_id = local.hub_virtual_network_id
      hub_peering_enabled     = true
      hub_peering_options_tohub = {
        use_remote_gateways = false
      }

      # Virtual WAN instead: remove the three hub_peering lines above and use
      # these. secure_internet_traffic sends internet-bound traffic through the
      # secured hub's firewall; routing_intent_enabled matches the hub.
      # vwan_connection_enabled = true
      # vwan_hub_resource_id    = local.virtual_hub_id
      # vwan_security_configuration = {
      #   routing_intent_enabled  = true
      #   secure_internet_traffic = true
      # }

      subnets = {
        # Private endpoints and anything without a delegation.
        workload = {
          name                   = "snet-${local.purpose}-workload-${local.context.environment}-${local.context.location_short}"
          address_prefixes       = ["10.16.0.0/26"]
          network_security_group = { key_reference = "workload" }
          # With route_table_enabled = true, send this subnet through the firewall:
          # route_table = { key_reference = "to_firewall" }
        }

        # App Service regional VNet integration needs a subnet of its own,
        # delegated to Microsoft.Web/serverFarms and used by no other service.
        appsvc = {
          name                   = "snet-${local.purpose}-appsvc-${local.context.environment}-${local.context.location_short}"
          address_prefixes       = ["10.16.0.64/26"]
          network_security_group = { key_reference = "workload" }

          delegations = [
            {
              name               = "appservice"
              service_delegation = { name = "Microsoft.Web/serverFarms" }
            }
          ]
        }
      }
    }
  }
}
