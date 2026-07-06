# terragrunt.stack.hcl
#
# Virtual WAN connectivity hub for this customer. Wraps the catalog's
# caf-connectivity-vwan stack at a pinned tag: the hub resource group plus a
# single-region Virtual WAN with Azure Firewall, deployed into the connectivity
# subscription named in subscription.hcl.
#
# Deployed from this folder because subscription.hcl and region.hcl are
# inherited from the two ancestor folders above (live/platform/connectivity/),
# not co-located here, so the connectivity subscription id and region are set
# once for the whole connectivity MG.
#
# This is the minimal hub that has been validated: firewall on (Basic), and
# DDoS, private DNS, gateways, and bastion off. The unit is safe by default:
# every optional cost-bearing resource stays off unless a hub opts in. Turn them
# on per hub in virtual_wan.virtual_hubs / virtual_wan.virtual_wan_settings
# below as the customer needs them. If you enable the DDoS protection plan and
# private DNS zones, also wire the foundation policy default values (set
# landing_zones.connectivity_subscription_id and the DDoS/DNS names in
# live/platform/management/westeurope/caf-platform-foundation/terragrunt.stack.hcl)
# so the ALZ policy assignments point at the live resources.

locals {
  catalog_url = "git::https://github.com/nrit-solutions/nrit-terragrunt-catalog.git"

  # Single source of truth for the catalog version. The stack block ?ref and
  # values.catalog_ref both render from this, so the stack and its units can
  # never resolve at different tags.
  catalog_version = "v1.0.0"

  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Region short code, used in the connectivity resource names (no customer prefix
  # and no sequence number, matching the ALZ accelerator convention).
  # customer_name is used only in tags. Set both during onboarding.
  customer_name  = "customer"
  location_short = local.region_vars.locals.location_short
  environment    = local.region_vars.locals.environment

  # owner, criticality, and confidentiality below are placeholders: set them
  # per the customer during onboarding. They are mandatory RG tags under the
  # nrit tag governance (see ONBOARDING.md, step 2).
  tags = {
    customer        = local.customer_name
    environment     = local.environment
    "cost-center"   = "platform"
    workload        = "alz-connectivity-vwan"
    owner           = "platform-team"
    criticality     = "medium"
    confidentiality = "internal"
    "managed-by"    = "terraform"
  }
}

stack "caf_connectivity_vwan" {
  source = "${local.catalog_url}//stacks/caf-connectivity-vwan?ref=${local.catalog_version}"
  path   = "caf-connectivity-vwan"
  values = {
    # Pin the catalog once: the source ?ref and catalog_ref render from the same
    # local, and catalog_url is forwarded so the units resolve from the same host.
    catalog_ref = local.catalog_version
    catalog_url = local.catalog_url

    # Names the hub resource group and feeds every hub's parent-id computation.
    hub_resource_group_name = "rg-vwan-hub-${local.location_short}"

    tags             = local.tags
    enable_telemetry = false

    # All Virtual WAN config lives in the virtual_wan namespace. One stack
    # instance owns the WAN and all its regional hubs: add a hub per region as an
    # entry in virtual_hubs and set its address space per entry.
    virtual_wan = {
      virtual_hubs = {
        weu = {
          default_hub_address_space = "10.0.0.0/16"
          hub                       = { name = "vhub-hub-${local.location_short}" }

          # Minimal validated hub: firewall on (Basic). DDoS, private DNS,
          # gateways, and bastion stay off because the unit defaults every
          # optional resource off; opt in by adding its enabled_resources flag.
          enabled_resources = { firewall = true }
          firewall          = { name = "fw-hub-${local.location_short}", sku_tier = "Basic" }
          firewall_policy   = { name = "fwp-hub-${local.location_short}" }
        }
      }

      # The unit disables the WAN-level DDoS plan by default (roughly EUR 2.5k a
      # month). Enable it with enabled_resources.ddos_protection_plan = true here.
      virtual_wan_settings = {
        virtual_wan = { name = "vwan-hub-${local.location_short}" }
      }
    }
  }
}
