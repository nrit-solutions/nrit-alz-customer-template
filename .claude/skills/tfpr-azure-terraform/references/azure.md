# Azure specifics

The Azure layer of the platform: state, authentication, providers, modules,
and the few places where the obvious Terraform resource is the wrong one.

## Contents

- [State backend](#state-backend)
- [Authentication](#authentication)
- [Providers](#providers)
- [Provider registration](#provider-registration)
- [Azure Verified Modules](#azure-verified-modules)
- [azapi for what azurerm cannot plan](#azapi-for-what-azurerm-cannot-plan)
- [The alz provider needs values known at plan time](#the-alz-provider-needs-values-known-at-plan-time)
- [Names and tags](#names-and-tags)

## State backend

- One storage account in the management subscription holds every unit's
  state, one blob per unit, keyed by the unit's path. The bootstrap creates it
  before the first plan. Terragrunt's own backend creation for azurerm is
  experimental and is not used.
- Access is by Entra ID: `use_azuread_auth = true`, and shared key access is
  disabled on the account. An identity needs a Storage Blob Data role on the
  container, and Owner or Contributor on the account is not enough.
- The backend subscription is read from `AZURE_SUBSCRIPTION_ID`, separately
  from the unit's deploy subscription in `subscription.hcl`.
- You never run `init` against the real backend from a shell. Offline work
  uses `init -backend=false`. See [hierarchy.md](hierarchy.md#validating-offline).

## Authentication

CI authenticates with Entra workload identity federation (OIDC) through the
`plan` and `apply` GitHub environments. There is no client secret and no
storage key anywhere, and the environment names are part of the federated
credential subjects, so they never change. Locally, `az login` is enough for
read-only work. `AGENTS.md` lists the `az` commands that never run without an
explicit instruction.

## Providers

`root.hcl` generates the default set into every unit:

| Provider | Constraint | Pinned to |
| --- | --- | --- |
| `hashicorp/azurerm` | `~> 4.0` | The unit's subscription and tenant |
| `Azure/azapi` | `~> 2.4` | The unit's subscription and tenant |
| `hashicorp/azuread` | `~> 3.10` | The tenant only |

The `~>` constraint sets the range. The committed `.terraform.lock.hcl` picks
the version. A unit declares no `required_providers` and no `provider` block of
its own, unless it overrides the whole set as described in
[unit-anatomy.md](unit-anatomy.md#terragrunthcl).

## Provider registration

Neither generated provider registers resource providers. `azurerm` sets
`resource_provider_registrations = "none"` and `azapi` sets
`skip_provider_registration = true`. The plan identity is not meant to
register namespaces on every run.

So a subscription must have its namespaces registered before a unit deploys
into it. For a landing zone, the `lz-vending` unit registers them through the
sub-vending module, and the list grows with the workloads. For the management
subscription, the bootstrap does it. Any other subscription, platform ones
included, needs its namespaces registered before the first unit deploys into
it. A plan that fails with
`MissingSubscriptionRegistration` means a namespace is missing from that list,
not that the provider block should change.

## Azure Verified Modules

- Source public AVM modules from the Terraform registry. No git sources, no
  local module folders, no private registry.
- Pin an exact `version`. No `~>` on a module. tflint enforces this with
  `terraform_module_version` set to `exact`.
- Set `enable_telemetry = false` on every AVM module call.
- `Azure/naming/azurerm` is the one non-AVM registry module allowed, for
  generated names with a length limit. It takes an exact `version` too, and has
  no `enable_telemetry`.
- Where no AVM module fits, a plain resource is fine.
- Read the module's inputs on the registry page for the pinned version, not
  the latest one. Module examples on GitHub are a good starting point and are
  tested by the module's own CI.
- Many AVM modules declare `azapi_resource` rather than an `azurerm_*` type.
  A conftest rule keyed only on the azurerm type matches nothing and reports a
  clean gate. See [Gates](https://docs.nrit.cloud/operations/gates/).

## azapi for what azurerm cannot plan

Manage Event Grid event subscriptions with `azapi_resource`. The azurerm
resources read a subscription back through the `getFullUrl` action, which the
read-only plan identity cannot call, so every plan after the first apply fails
with 403. azapi reads with a plain GET:

```hcl
resource "azapi_resource" "orders_to_queue" {
  type      = "Microsoft.EventGrid/systemTopics/eventSubscriptions@2022-06-15"
  name      = "evgs-orders-${local.context.environment}-${local.context.location_short}"
  parent_id = local.system_topic_id

  body = {
    properties = {
      destination = {
        endpointType = "StorageQueue"
        properties = {
          resourceId = local.storage_account_id
          queueName  = "orders"
        }
      }
      eventDeliverySchema = "EventGridSchema"
    }
  }
}
```

Pick a current API version from the Azure REST reference. The same reasoning
applies to any resource whose azurerm read calls a POST action: if a plan fails
with 403 on a read the first apply passed, look at how the resource is read.

## The alz provider needs values known at plan time

The `alz` provider, used by `_foundation/landing-zones` and `_foundation/amba`,
reads its data sources during plan and rejects unknown values. Build every
policy default value from names, never from a module output or a resource
attribute:

```hcl
locals {
  management_scope = "/subscriptions/${local.management_subscription_id}/resourceGroups/rg-management-${local.context.location_short}/providers"

  # Known at plan time: a string built from names.
  log_analytics_workspace_id = "${local.management_scope}/Microsoft.OperationalInsights/workspaces/log-management-${local.context.location_short}"
}
```

Reading `module.management.workspace_id` instead fails the plan. The producer
and the consumer then share a naming rule, so comment it on both sides.

## Names and tags

The naming rule, the length exceptions and the house tag block are in
`AGENTS.md`, under **Naming** and **Tags**. In short:

- Platform units: `<abbreviation>-<purpose>-<region>`, for example
  `log-management-weu`, `id-management-ama-weu`, `afw-hub-weu`.
- Landing zone units: `<abbreviation>-<purpose>-<environment>-<region>`, for
  example `vnet-corp-prod-weu`, `kv-app-prod-weu`.
- Abbreviations come from the CAF
  [abbreviation list](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).
- Storage accounts take no hyphens and cap at 24 characters:
  `st<purpose><env><loc><instance>`, often generated with `Azure/naming/azurerm`.
- Never rename an existing resource to match a newer convention. Azure names
  cannot change, so a rename is a destroy and a create.
- Set tags explicitly on a virtual network as well as its resource group, or
  the inherit-tag policy makes it drift on every plan.

## References

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [AVM modules on the Terraform registry](https://registry.terraform.io/namespaces/Azure)
- [azurerm backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [Azure resource name rules](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules)
