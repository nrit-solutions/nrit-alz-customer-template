locals {
  # <archetype>-<purpose>-<environment>, the same as the folder name. The alias
  # is the API-side name and cannot change later; the display name can.
  subscription_display_name = "corp-app-prod"
  subscription_alias_name   = "corp-app-prod"

  # The billing scope the subscription is created under. For an Enterprise
  # Agreement it is an enrollment account, for a Microsoft Customer Agreement an
  # invoice section, for a partner (CSP) a customer. Case sensitive. The apply
  # identity needs the subscription creator role on it; see the scenario page.
  subscription_billing_scope = "/providers/Microsoft.Billing/billingAccounts/00000000/enrollmentAccounts/000000"

  # Microsoft.AlertsManagement and microsoft.insights are what AMBA needs on every subscription.
  resource_providers = {
    "Microsoft.AlertsManagement"    = []
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

  # Vend a new subscription from the billing scope.
  subscription_alias_enabled = true
  subscription_alias_name    = local.subscription_alias_name
  subscription_display_name  = local.subscription_display_name
  subscription_billing_scope = local.subscription_billing_scope
  subscription_workload      = "Production"

  # Tags on the subscription itself. The ALZ inherit-tag policy copies
  # businessunit, env and costcenter from here onto every resource group that
  # lacks them, so this is the place for the three subscription-level tags.
  subscription_tags = {
    businessunit = local.context.business_unit
    env          = local.context.environment
    costcenter   = "app"
  }

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
