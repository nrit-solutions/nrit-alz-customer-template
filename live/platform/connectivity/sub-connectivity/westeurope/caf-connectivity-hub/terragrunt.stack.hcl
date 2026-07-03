# terragrunt.stack.hcl
#
# Virtual WAN connectivity hub for this customer. Wraps the catalog's
# caf-connectivity-vwan stack at a pinned tag: the hub resource group plus a
# single-region Virtual WAN with Azure Firewall, deployed into the connectivity
# subscription named in subscription.hcl.
#
# This is the minimal hub that has been validated: firewall on (Basic), and DDoS,
# private DNS, gateways, and bastion off. Turn those on in primary_hub /
# virtual_wan_settings below as the customer needs them. If you enable the DDoS
# protection plan and private DNS zones, also wire the foundation policy default
# values (set connectivity_subscription_id and the DDoS/DNS names in
# live/tenant/_global/caf-platform-foundation/terragrunt.stack.hcl) so the ALZ
# policy assignments point at the live resources.

locals {
  catalog_url = "git::https://github.com/nrit-solutions/nrit-terragrunt-catalog.git"
  catalog_ref = "v0.4.2"

  # Region short code, used in the connectivity resource names (no customer prefix
  # and no sequence number, matching the ALZ accelerator convention).
  # customer_name is used only in tags. Set both during onboarding.
  customer_name  = "customer"
  location_short = "weu"
  environment    = "prod"

  tags = {
    customer     = local.customer_name
    environment  = local.environment
    workload     = "alz-connectivity-vwan"
    "managed-by" = "terraform"
  }
}

stack "caf_connectivity_vwan" {
  source = "${local.catalog_url}//stacks/caf-connectivity-vwan?ref=${local.catalog_ref}"
  path   = "caf-connectivity-vwan"
  values = {
    hub_resource_group_name = "rg-vwan-hub-${local.location_short}"
    hub_address_space       = "10.0.0.0/16"

    primary_hub = {
      hub = {
        name = "vhub-hub-${local.location_short}"
      }
      enabled_resources = {
        firewall                              = true
        bastion                               = false
        virtual_network_gateway_vpn           = false
        virtual_network_gateway_express_route = false
        private_dns_zones                     = false
        private_dns_resolver                  = false
        sidecar_virtual_network               = false
      }
      firewall = {
        name     = "fw-hub-${local.location_short}"
        sku_tier = "Basic"
      }
      firewall_policy = {
        name = "fwp-hub-${local.location_short}"
      }
    }

    virtual_wan_settings = {
      virtual_wan = {
        name = "vwan-hub-${local.location_short}"
      }
      enabled_resources = {
        ddos_protection_plan = false
      }
    }

    tags             = local.tags
    enable_telemetry = false
  }
}
