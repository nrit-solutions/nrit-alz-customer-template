data "azapi_client_config" "current" {}

locals {
  location       = "westeurope"
  location_short = "weu"

  management_subscription_id   = data.azapi_client_config.current.subscription_id
  connectivity_subscription_id = "00000000-0000-0000-0000-000000000000"

  # These management resource names must match the management leaf: it creates
  # the resources, the policy default values below point at them by id. Keep the
  # two in sync.
  management_resource_group_name          = "rg-management-${local.location_short}"
  log_analytics_workspace_name            = "law-management-${local.location_short}"
  ama_user_assigned_managed_identity_name = "uami-management-ama-${local.location_short}"
  dcr_change_tracking_name                = "dcr-change-tracking-${local.location_short}"
  dcr_vm_insights_name                    = "dcr-vm-insights-${local.location_short}"
  dcr_defender_sql_name                   = "dcr-defender-sql-${local.location_short}"

  subscription_placement = {
    connectivity = {
      subscription_id       = local.connectivity_subscription_id
      management_group_name = "connectivity"
    }
    management = {
      subscription_id       = local.management_subscription_id
      management_group_name = "management"
    }
  }

  # Tag governance stays in Audit while resource groups are reconciled; the
  # placeholder DDoS assignment is disabled so VNet creates work.
  policy_assignments_to_modify = {
    alz = {
      policy_assignments = {
        Enforce-Tag-Gov = {
          parameters = {
            rgMandatoryTagsEffect = jsonencode({ value = "Audit" })
            criticalityEffect     = jsonencode({ value = "Audit" })
            confidentialityEffect = jsonencode({ value = "Audit" })
            environmentEffect     = jsonencode({ value = "Audit" })
          }
        }
      }
    }
    connectivity = {
      policy_assignments = {
        Enable-DDoS-VNET = { creation_enabled = false }
      }
    }
    landingzones = {
      policy_assignments = {
        Enable-DDoS-VNET = { creation_enabled = false }
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Recommended production hardening (reference, commented out).
  #
  # NRIT's recommended settings to move a production landing zone from the soft
  # AVM default posture to enforced. Do NOT enable everything at once: follow the
  # safe-deployment approach (platform docs: Azure Policy > Enforcement strategy).
  # Enable a wave scoped to sandbox or one region first with resource_selectors,
  # validate compliance, then expand. To use, lift the entries you want into
  # policy_assignments_to_modify above, merging by management group key.
  #
  # prod_hardening = {
  #   # Tag governance: enforce the baseline tags once resource groups are clean.
  #   alz = {
  #     policy_assignments = {
  #       Enforce-Tag-Gov = {
  #         parameters = {
  #           rgMandatoryTagsEffect = jsonencode({ value = "Deny" })
  #           criticalityEffect     = jsonencode({ value = "Deny" })
  #           confidentialityEffect = jsonencode({ value = "Deny" })
  #           environmentEffect     = jsonencode({ value = "Deny" })
  #         }
  #       }
  #     }
  #   }
  #
  #   # Enforce-Guardrails: the per-service guardrail initiatives ship in
  #   # DoNotEnforce. Switch to Default to enforce. The same set exists at the
  #   # platform scope; enforce there too when the platform subscriptions are ready.
  #   landingzones = {
  #     policy_assignments = {
  #       # Wave 1 - data services (lowest workload-breakage risk)
  #       Enforce-GR-Storage0     = { enforcement_mode = "Default" }
  #       Enforce-GR-KeyVaultSup0 = { enforcement_mode = "Default" }
  #       Enforce-GR-SQL0         = { enforcement_mode = "Default" }
  #       Enforce-GR-MySQL0       = { enforcement_mode = "Default" }
  #       Enforce-GR-PostgreSQL0  = { enforcement_mode = "Default" }
  #       Enforce-GR-CosmosDb0    = { enforcement_mode = "Default" }
  #       Enforce-GR-DataExpl0    = { enforcement_mode = "Default" }
  #       Enforce-GR-DataFactory0 = { enforcement_mode = "Default" }
  #       Enforce-GR-Synapse0     = { enforcement_mode = "Default" }
  #       Enforce-GR-EventHub0    = { enforcement_mode = "Default" }
  #       Enforce-GR-EventGrid0   = { enforcement_mode = "Default" }
  #       Enforce-GR-ServiceBus0  = { enforcement_mode = "Default" }
  #
  #       # Wave 2 - compute, containers, network, apps (validate against running workloads first)
  #       Enforce-GR-Compute0     = { enforcement_mode = "Default" }
  #       Enforce-GR-Network0     = { enforcement_mode = "Default" }
  #       Enforce-GR-Kubernetes0  = { enforcement_mode = "Default" }
  #       Enforce-GR-AppServices0 = { enforcement_mode = "Default" }
  #       Enforce-GR-ContApps0    = { enforcement_mode = "Default" }
  #       Enforce-GR-ContInst0    = { enforcement_mode = "Default" }
  #       Enforce-GR-ContReg0     = { enforcement_mode = "Default" }
  #       Enforce-GR-Automation0  = { enforcement_mode = "Default" }
  #       Enforce-GR-APIM0        = { enforcement_mode = "Default" }
  #       Enforce-GR-CogServ0     = { enforcement_mode = "Default" }
  #       Enforce-GR-MachLearn0   = { enforcement_mode = "Default" }
  #       Enforce-GR-OpenAI0      = { enforcement_mode = "Default" }
  #       Enforce-GR-BotService0  = { enforcement_mode = "Default" }
  #       Enforce-GR-VirtualDesk0 = { enforcement_mode = "Default" }
  #
  #       # Private subnets: confirm workload subnets comply before enforcing.
  #       Enforce-Subnet-Private  = { enforcement_mode = "Default" }
  #
  #       # Customer-managed keys: enforce last, and only where key infrastructure
  #       # exists per workload; expect breakage otherwise.
  #       # Enforce-Encrypt-CMK0  = { enforcement_mode = "Default" }
  #     }
  #   }
  # }
  # ---------------------------------------------------------------------------

  # Policy default values, computed from the management resource names so every
  # id is known at plan time (the alz provider reads a data source at plan and
  # cannot take unknown values).
  management_providers_scope = "/subscriptions/${local.management_subscription_id}/resourceGroups/${local.management_resource_group_name}/providers"
  policy_default_values_raw = {
    log_analytics_workspace_id                  = "${local.management_providers_scope}/Microsoft.OperationalInsights/workspaces/${local.log_analytics_workspace_name}"
    ama_change_tracking_data_collection_rule_id = "${local.management_providers_scope}/Microsoft.Insights/dataCollectionRules/${local.dcr_change_tracking_name}"
    ama_vm_insights_data_collection_rule_id     = "${local.management_providers_scope}/Microsoft.Insights/dataCollectionRules/${local.dcr_vm_insights_name}"
    ama_mdfc_sql_data_collection_rule_id        = "${local.management_providers_scope}/Microsoft.Insights/dataCollectionRules/${local.dcr_defender_sql_name}"
    ama_user_assigned_managed_identity_id       = "${local.management_providers_scope}/Microsoft.ManagedIdentity/userAssignedIdentities/${local.ama_user_assigned_managed_identity_name}"
    ama_user_assigned_managed_identity_name     = local.ama_user_assigned_managed_identity_name
  }
  policy_default_values = { for key, value in local.policy_default_values_raw : key => jsonencode({ value = value }) }
}

module "management_groups" {
  source  = "Azure/avm-ptn-alz/azurerm"
  version = "0.21.0"

  # Must match an architecture defined in the alz library referenced by
  # terragrunt.hcl (the catalog library_references entry). Set per customer.
  architecture_name  = "changeme"
  parent_resource_id = data.azapi_client_config.current.tenant_id
  location           = local.location
  enable_telemetry   = false

  subscription_placement       = local.subscription_placement
  policy_assignments_to_modify = local.policy_assignments_to_modify
  policy_default_values        = local.policy_default_values
}
