# parent_resource_id used to come from the authenticated session, so it could
# not be wrong. It now comes from tenant.hcl, which falls back to a placeholder
# when AZURE_TENANT_ID is unset, so fail the plan rather than parent the whole
# hierarchy under a management group that does not exist.
data "azapi_client_config" "current" {
  lifecycle {
    precondition {
      condition = !contains(
        ["", "00000000-0000-0000-0000-000000000000"],
        local.context.tenant_root_id,
      )
      error_message = "tenant_root_id is unset or still the placeholder. It defaults to tenant_id in live/tenant.hcl, so this usually means AZURE_TENANT_ID is not exported. Export AZURE_TENANT_ID, or set tenant_root_id in live/tenant.hcl to the customer's existing intermediate management group id."
    }
  }
}

locals {

  management_subscription_id = data.azapi_client_config.current.subscription_id

  # Leave empty if the customer has no connectivity subscription: the
  # connectivity placement entry below is then omitted rather than sent with a
  # placeholder id, which apply rejects.
  connectivity_subscription_id = ""

  # These management resource names must match the management leaf: it creates
  # the resources, the policy default values below point at them by id. Keep the
  # two in sync.
  management_resource_group_name          = "rg-management-${local.context.environment}-${local.context.location_short}"
  log_analytics_workspace_name            = "law-management-${local.context.environment}-${local.context.location_short}"
  ama_user_assigned_managed_identity_name = "uami-management-ama-${local.context.environment}-${local.context.location_short}"
  dcr_change_tracking_name                = "dcr-change-tracking-${local.context.environment}-${local.context.location_short}"
  dcr_vm_insights_name                    = "dcr-vm-insights-${local.context.environment}-${local.context.location_short}"
  dcr_defender_sql_name                   = "dcr-defender-sql-${local.context.environment}-${local.context.location_short}"

  subscription_placement = merge(
    {
      management = {
        subscription_id       = local.management_subscription_id
        management_group_name = "management"
      }
    },
    local.connectivity_subscription_id == "" ? {} : {
      connectivity = {
        subscription_id       = local.connectivity_subscription_id
        management_group_name = "connectivity"
      }
    },
  )

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
  # Common customizations (reference, commented out).
  #
  # The stock ALZ settings customers most often change on day one. Lift the
  # entries you want into policy_assignments_to_modify above (merge by management
  # group key). To move guardrails and tag effects to enforced, see the
  # "Recommended production hardening" block below and the platform docs
  # (Azure Policy > Enforcement strategy).
  #
  # common_customizations = {
  #   alz = {
  #     policy_assignments = {
  #       # Microsoft Defender for Cloud. Set your real security contact email
  #       # (it ships as a placeholder), and enable the plans you want: each plan
  #       # ships "Disabled"; "DeployIfNotExists" turns it on. Enabled plans cost.
  #       Deploy-MDFC-Config-H224 = {
  #         parameters = {
  #           emailSecurityContact    = jsonencode({ value = "soc@your-domain.com" })
  #           enableAscForServers     = jsonencode({ value = "DeployIfNotExists" })
  #           enableAscForStorage     = jsonencode({ value = "DeployIfNotExists" })
  #           enableAscForContainers  = jsonencode({ value = "DeployIfNotExists" })
  #           enableAscForKeyVault    = jsonencode({ value = "DeployIfNotExists" })
  #           enableAscForAppServices = jsonencode({ value = "DeployIfNotExists" })
  #           enableAscForSql         = jsonencode({ value = "DeployIfNotExists" })
  #           enableAscForArm         = jsonencode({ value = "DeployIfNotExists" })
  #           # ...enableAscForOssDb, enableAscForCosmosDbs, enableAscForCspm,
  #           #    enableAscForSqlOnVm, enableAscForServersVulnerabilityAssessments
  #         }
  #       }
  #     }
  #   }
  # }
  #
  # DDoS Protection is opted out in the active config above (Enable-DDoS-VNET
  # creation_enabled = false) so VNet creates work without a plan. In production,
  # flip those two entries to creation_enabled = true to enforce a DDoS plan
  # (it carries a monthly cost).
  #
  # Modify capabilities you can apply to any assignment (docs: Azure Policy >
  # Customizing policies). Each is an attribute of the assignment object:
  #
  #   # Evaluate without acting (safe-deployment "what if").
  #   <Assignment> = { enforcement_mode = "DoNotEnforce" }
  #
  #   # Opt out of a control entirely.
  #   <Assignment> = { creation_enabled = false }
  #
  #   # Change a parameter / effect.
  #   <Assignment> = { parameters = { <param> = jsonencode({ value = "Deny" }) } }
  #
  #   # Phased rollout (safe deployment): enforce in one region first, then widen
  #   # the list. This is the recommended way to turn a guardrail on. See the
  #   # platform docs, Azure Policy > Enforcement strategy.
  #   <Assignment> = {
  #     enforcement_mode = "Default"
  #     resource_selectors = [{
  #       name                        = "phased-rollout"
  #       resource_selector_selectors = [{ kind = "resourceLocation", in = ["westeurope"] }]
  #     }]
  #   }
  #
  #   # Exclude a scope from evaluation (a test subscription, a legacy RG).
  #   <Assignment> = { not_scopes = ["/subscriptions/<id>/resourceGroups/<rg>"] }
  #
  #   # Override the effect of specific policies inside an initiative.
  #   <Assignment> = {
  #     overrides = [{
  #       kind               = "policyEffect"
  #       value              = "Disabled"
  #       override_selectors = [{ kind = "policyDefinitionReferenceId", in = ["<referenceId>"] }]
  #     }]
  #   }
  #
  #   # Custom non-compliance message (may not always produce a plan diff).
  #   <Assignment> = { non_compliance_messages = [{ message = "..." }] }
  #
  # For a one-off, time-bound exception on a specific resource, prefer an Azure
  # Policy exemption (a separate resource, tracked, with an expiry) over not_scopes.
  # ---------------------------------------------------------------------------

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
  # terragrunt.hcl. The vendored lib/ defines one: nrit.
  architecture_name  = "nrit"
  parent_resource_id = local.context.tenant_root_id
  location           = local.context.location
  enable_telemetry   = false

  subscription_placement       = local.subscription_placement
  policy_assignments_to_modify = local.policy_assignments_to_modify
  policy_default_values        = local.policy_default_values
}
