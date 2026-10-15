data "azapi_client_config" "current" {}

locals {
  # The subscription this leaf adopts. The providers are pinned to it
  # (subscription.hcl), so the client-config subscription is that subscription.
  subscription_id = data.azapi_client_config.current.subscription_id

  # <archetype>-<purpose>-<environment>, the same as the folder name.
  subscription_display_name = "corp-app-prod"

  resource_providers = {
    "Microsoft.KeyVault"            = []
    "Microsoft.ManagedIdentity"     = []
    "Microsoft.OperationalInsights" = []
    "Microsoft.Storage"             = []
    "Microsoft.Web"                 = []
    "microsoft.insights"            = []
  }
}

module "subscription_vending" {
  source  = "Azure/avm-ptn-alz-sub-vending/azure"
  version = "0.3.4"

  location = local.context.location

  # Adopt the existing subscription; do not vend a new one.
  subscription_alias_enabled = false
  subscription_id            = local.subscription_id

  # update_existing is what activates the module's rename action against the
  # adopted subscription; without it display_name is inert.
  subscription_update_existing = true
  subscription_display_name    = local.subscription_display_name

  # update_existing also makes the module own the subscription tags object, and
  # an empty map keeps it unmanaged. The ALZ inherit-tag policy copies
  # businessunit, env and costcenter down from here, so set them on the
  # resource groups instead unless you want every resource restamped.
  subscription_tags = {}

  # Place the subscription under its archetype. "corp" for a corp-connected
  # landing zone, "online" for an internet-facing one; nothing else differs.
  subscription_management_group_id                  = "corp"
  subscription_management_group_association_enabled = true

  # The root provider block registers nothing, and a fresh subscription lacks
  # most providers a workload needs. Registration is an idempotent POST, so an
  # already-registered provider is a no-op. Add to the list as workloads arrive.
  subscription_register_resource_providers_enabled      = true
  subscription_register_resource_providers_and_features = local.resource_providers

  # The monthly cost ceiling, in the billing currency. Owner notifications reach
  # whoever holds Owner on the subscription, including inherited assignments,
  # so no address is committed here.
  budget_enabled = true
  budgets = {
    monthly = {
      name              = "budget-${local.subscription_display_name}-monthly"
      amount            = 500
      time_grain        = "Monthly"
      time_period_start = "2026-11-01T00:00:00Z"
      time_period_end   = "2027-10-31T23:59:59Z"
      notifications = {
        actual80 = {
          enabled       = true
          operator      = "GreaterThan"
          threshold     = 80
          contact_roles = ["Owner"]
        }
        forecast100 = {
          enabled        = true
          operator       = "GreaterThan"
          threshold      = 100
          threshold_type = "Forecasted"
          contact_roles  = ["Owner"]
        }
      }
    }
  }

  # Identities and RBAC belong to the workload units, next to what they own.
  umi_enabled             = false
  role_assignment_enabled = false

  enable_telemetry = false
}
