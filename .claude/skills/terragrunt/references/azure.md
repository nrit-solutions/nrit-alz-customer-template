# Terragrunt on Azure (azurerm backend, ALZ/CAF)

This is the Azure-specific layer for an ALZ/CAF estate. Cloud-agnostic patterns
are in the other reference files; this file is the Azure delta.

## State backend: azurerm

> ⚠️ Auto-provisioning of the storage account/container via `remote_state` is
> **experimental** on Azure (gated behind `TG_EXPERIMENT=azure-backend`) and not
> mature. **Pre-create the RG + Storage Account + container yourself** (a
> bootstrap unit or a one-time script), then let Terragrunt only generate the
> backend config. For azurerm, `remote_state` mostly behaves like a `generate`
> block today.

### Recommended `remote_state` block (Entra ID auth, no storage keys)

Read the backend coordinates from the Action variables the bootstrap set and the
reusable workflow exports, with placeholder fallbacks so the whole tree
generates and validates offline (`init -backend=false`) with no Azure access.
One shared state account (in the management sub) can back every subscription, so
its subscription is read separately from the per-folder `subscription.hcl`.

```hcl
remote_state {
  backend  = "azurerm"
  generate = { path = "backend.tf", if_exists = "overwrite_terragrunt" }
  config = {
    resource_group_name  = get_env("BACKEND_AZURE_RESOURCE_GROUP_NAME", "placeholder-rg")
    storage_account_name = get_env("BACKEND_AZURE_STORAGE_ACCOUNT_NAME", "placeholdersa")
    container_name       = get_env("BACKEND_AZURE_STORAGE_ACCOUNT_CONTAINER_NAME", "tfstate")
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    subscription_id      = get_env("AZURE_SUBSCRIPTION_ID", local.subscription_id)  # backend sub, may differ from the deploy sub
    tenant_id            = local.tenant_id                                          # from tenant.hcl
    use_azuread_auth     = true        # Entra ID data-plane auth, no SA access keys
  }
}
```

`use_azuread_auth = true` (or `ARM_USE_AZUREAD=true`) means the identity needs
**Storage Blob Data Contributor** on the state container — no storage account
keys are used or stored.

### Generated provider block

```hcl
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "azurerm" {
  features {}
  subscription_id     = "${local.subscription_vars.locals.subscription_id}"
  tenant_id           = "${local.subscription_vars.locals.tenant_id}"
  storage_use_azuread = true
  use_oidc            = true   # CI: workload identity federation
}
EOF
}
```

Generating the provider per-unit in `root.hcl` avoids a historical azurerm gotcha
where SP auth didn't propagate to child modules.

## Authentication

| Context | Pattern |
|---|---|
| Local dev | Azure CLI (`az login`) — azurerm picks it up; or set `ARM_*`. |
| CI (preferred) | **OIDC / workload identity federation**: `ARM_USE_OIDC=true`, `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID` — no stored secret. |
| CI (fallback) | Service principal: `ARM_CLIENT_ID`/`ARM_CLIENT_SECRET`/`ARM_TENANT_ID`/`ARM_SUBSCRIPTION_ID` (secret as a masked CI variable). |
| State data plane | `use_azuread_auth = true` / `ARM_USE_AZUREAD=true` → RBAC, not keys. |

## ALZ / CAF layout

Mirror the management-group tree **directly under `live/`**. A folder path equals
its MG path and names the real subscription, so a folder maps to the portal with
no key. Where an MG holds exactly one subscription (every platform MG today),
collapse the MG and sub into one folder. Landing-zone MGs keep the two-level
shape because they can hold more than one sub.

```
live/
├── root.hcl
├── tenant.hcl                     # tenant_id + tenant_root_id (ancestor of all)
├── _foundation/                   # tenant governance, ABOVE any sub or region
│   ├── subscription.hcl           # the management sub it is operated from
│   ├── region.hcl                 # primary region
│   ├── management-resources/      # LAW + DCRs + AMA identity
│   │   ├── terragrunt.hcl
│   │   └── main.tf
│   ├── landing-zones/             # MG tree + policy + subscription placement
│   │   ├── terragrunt.hcl         #   alz + azapi, merge_strategy = "deep"
│   │   ├── main.tf
│   │   └── lib/                   #   vendored custom policy library
│   └── amba/                      # AMBA resources + AMBA policy, one state
├── platform/
│   ├── connectivity/              # MG = sub (collapsed)
│   │   ├── subscription.hcl       # subscription_id
│   │   └── westeurope/
│   │       ├── region.hcl         # location, location_short, environment
│   │       └── caf-connectivity-hub/
│   │           ├── terragrunt.hcl
│   │           └── main.tf        # hub vnet, firewall, dns …
│   ├── management/                # MG = sub; genuine management-sub workloads
│   ├── identity/                  # MG, no sub yet (placeholder folder)
│   └── security/
└── landingzones/
    └── corp/                      # MG holds >1 sub, so keep the sub level
        └── corp-payments-prod/    # <archetype>-<purpose>-<env>, the real sub name
            ├── subscription.hcl
            ├── _global/           # region-agnostic: placement, budgets, RBAC
            │   ├── region.hcl     # nominal copy (root.hcl reads region.hcl always)
            │   └── lz-vending/
            └── westeurope/
                ├── region.hcl
                └── network/       # spoke VNet + subnets + hub peering
```

The foundation is **not** a workload of the management subscription and does not
multiply per region, so it sits at the top of `live/` with its own
`subscription.hcl` and `region.hcl`. Do not nest it under
`platform/management/<region>/`: that shape needs cross-tree references and is
only justified when data residency forces a per-region workspace.

It is three units, not one. Monitoring, policy, and AMBA each keep their own
state, so a change to one does not re-plan the others. Order is enforced with
`dependencies` blocks: management-resources, then landing-zones, then amba.

- `tenant_id` / `tenant_root_id` live in `tenant.hcl` at the repo root;
  `subscription_id` lives in each `subscription.hcl` (single source of truth, via
  `get_env`); backend SA/RG come from the reusable-workflow Action variables, not
  from `subscription.hcl`. Everything inherits through `root.hcl` into the
  generated provider + backend so each unit targets the correct subscription.
- Compute resource ids from **known names**, not from Terraform outputs: the tree
  uses `dependencies` (ordering only) and avoids `dependency`/`mock_outputs`
  entirely, so the mock-leaks-into-apply footgun never arises.
- A **one-time bootstrap** (RG + Storage Account with
  `shared_access_key_enabled = false` + `tfstate` container + RBAC) solves the
  azurerm chicken-and-egg, since auto-bootstrap can't be relied on.
- Prefer **public Azure Verified Modules from the Terraform registry**, called
  with an exact `version` and `enable_telemetry = false`. A repo on the catalog
  shape pins `?ref=<tag>` on its sources instead — follow the repo's
  `AGENTS.md` for which applies.

## The alz provider needs plan-time known values

The `alz` provider reads data sources during plan and cannot accept a value that
is unknown until apply. So a policy default value must be **computed from names**,
never read from a module output or a resource attribute:

```hcl
# right: every id is a string built from names the tree already knows
management_providers_scope = "/subscriptions/${local.management_subscription_id}/resourceGroups/${local.management_resource_group_name}/providers"
policy_default_values_raw = {
  log_analytics_workspace_id = "${local.management_providers_scope}/Microsoft.OperationalInsights/workspaces/${local.log_analytics_workspace_name}"
}

# wrong: unknown at plan time, the provider errors
log_analytics_workspace_id = module.management_resources.workspace_id
```

The cost is that the producing unit and the consuming unit share a naming rule.
Comment the coupling on both sides so it cannot drift.

## Resource naming (CAF)

CAF's component order is
`<type>-<purpose>-<environment>-<region>[-<instance>]` — and the environment
component belongs on **workload** resources, not on shared platform ones.
Environment is a property of the workload: a tenant has one management
workspace and one hub serving every environment, so `law-management-prod-weu`
would imply a sibling that cannot exist. CAF's own shared examples omit it
(`vnet-shared-eastus2-001`). In an ALZ tree that typically means:

| Unit lives under | Pattern | Example |
|---|---|---|
| foundation / platform | `<type>-<purpose>-<region>` | `rg-management-weu`, `vnet-hub-weu` |
| landing zones | `<type>-<purpose>-<environment>-<region>` | `vnet-corp-prod-weu` |

The repo's `AGENTS.md` states the exact house rule; follow it. Build names from
the hierarchy values (e.g. `local.context.location_short`,
`local.context.environment`) — never hardcode a region or environment. The
instance suffix (`001`) is decided at creation, because Azure names cannot be
changed afterwards. Types that allow no hyphens and cap at 24 characters
(storage accounts, key vaults) compress to `st<purpose><env><loc><instance>`.

Reference: https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming
and https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules

## Secrets: SOPS + Azure Key Vault

```hcl
# .sops.yaml declares an Azure Key Vault key for encryption
locals {
  secrets = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/secrets.enc.yaml"))
}
inputs = { sql_admin_password = local.secrets.sql_admin_password }
```
Encrypt with a Key Vault key (`sops --encrypt --azure-kv <key-url>`); commit only
the encrypted file. Better still, reference existing Key Vault secrets at runtime
via a `data "azurerm_key_vault_secret"` in the module to keep them out of state.

## Azure-specific review checks
- `use_azuread_auth = true` and `shared_access_key_enabled = false` on the state SA.
- OIDC / workload identity in CI, not a static SP secret.
- Correct `subscription_id` per provider (no cross-subscription drift).
- State SA hardened: private endpoint / firewall, versioning, soft delete.
- Every module is a registry AVM module at an exact `version`, with
  `enable_telemetry = false`.
- Policy default values computed from names, not from module outputs.
- Names follow the CAF guidance above (or the repo's stated convention) and
  read the hierarchy values, never hardcoded.

## References
- azurerm backend (HashiCorp) — https://developer.hashicorp.com/terraform/language/backend/azurerm
- Store Terraform state in Azure Storage (MS Learn) — https://learn.microsoft.com/azure/developer/terraform/store-state-in-azure-storage
- Terragrunt state backend feature — https://docs.terragrunt.com/features/units/state-backend/
- Azure Verified Modules — https://azure.github.io/Azure-Verified-Modules/
- CAF resource naming — https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming
- Azure resource name rules and limits — https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules
- For current azurerm/auth specifics, use the Microsoft Learn MCP
  (`microsoft_docs_search` / `microsoft_docs_fetch`).
