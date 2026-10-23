# Sharing values between units

Each unit has its own state, so one unit cannot reference another unit's
resources. Take the first option that fits, in this order. The earlier options
keep the unit at two files and couple nothing. The house rule is in
`AGENTS.md`, under **Sharing values between units**. The long form, with the
reasoning, is
[Sharing data between units](https://docs.nrit.cloud/operations/sharing-data-between-units/).

| You need | Use | Extra files |
| --- | --- | --- |
| B to apply after A, no value crosses | `dependencies` | none |
| A name you control | Convention: derive the same name in both units | none |
| A live value with a known name | A `data` source | none |
| A secret | Key Vault, read with `ephemeral` into a `*_wo` argument, or a service-side Key Vault reference | none |
| A computed value with no stable name | A `dependency` block | an output on the producer, a variable on the consumer |

## 1. Ordering: dependencies

```hcl
dependencies {
  paths = ["../network"]
}
```

Add one whenever a unit needs another to exist first, even when no value
crosses. Terragrunt orders only what is declared: nothing infers that all of
`_foundation/` precedes `platform/`.

## 2. Convention: derive the same name

Both units build the name from the same parts. The consumer rebuilds an id
from it when it needs one.

```hcl
# Must match the network unit's names. Change both together.
locals {
  network_resource_group_name = "rg-app-network-${local.context.environment}-${local.context.location_short}"
  spoke_virtual_network_name  = "vnet-app-${local.context.environment}-${local.context.location_short}"
  workload_subnet_id          = "/subscriptions/${local.context.subscription_id}/resourceGroups/${local.network_resource_group_name}/providers/Microsoft.Network/virtualNetworks/${local.spoke_virtual_network_name}/subnets/snet-app-workload-${local.context.environment}-${local.context.location_short}"
}
```

Comment the coupling on both sides. The values come from `local.context`, so
region and environment cannot drift between the two units.

This is also the only option that works for the `alz` provider, which needs
every policy default value known at plan time. See
[azure.md](azure.md#the-alz-provider-needs-values-known-at-plan-time).

## 3. Data source: look up by known name

For a value Azure computes but you can query, such as a principal id:

```hcl
data "azurerm_user_assigned_identity" "ama" {
  name                = "id-management-ama-${local.context.location_short}"
  resource_group_name = "rg-management-${local.context.location_short}"
}
```

Pair it with a `dependencies` path so the resource exists before the read.

## 4. Secrets: Key Vault, read ephemerally

A secret lives in Key Vault. The consumer reads it with an `ephemeral` block
and hands it to a write-only `*_wo` argument, so the value reaches neither the
plan nor the state:

```hcl
data "azurerm_key_vault" "workload" {
  name                = "kv-app-${local.context.environment}-${local.context.location_short}"
  resource_group_name = "rg-app-security-${local.context.environment}-${local.context.location_short}"
}

ephemeral "azurerm_key_vault_secret" "sql_admin" {
  name         = "sql-admin-password"
  key_vault_id = data.azurerm_key_vault.workload.id
}

resource "azurerm_mssql_server" "this" {
  # ...
  administrator_login_password_wo         = ephemeral.azurerm_key_vault_secret.sql_admin.value
  administrator_login_password_wo_version = 1
}
```

Terraform never stores a write-only value, so it cannot see a rotation. Bump
the `*_wo_version` number to send the new value.

Where the service reads Key Vault itself, let it. An App Service or Functions
app setting of the form `@Microsoft.KeyVault(SecretUri=...)`, or a Container
Apps secret with a Key Vault reference, resolves at runtime, and Terraform
never touches the value.

Two ways leak a secret into state, and both are wrong:

- A plain `data "azurerm_key_vault_secret"`. Its `value` is stored in the
  consumer's state.
- A `dependency` output. The value lands in the producer's and the consumer's
  state.

Writing a secret works the same way in reverse. See
[terraform-style.md](terraform-style.md#secrets-ephemeral-values-and-write-only-arguments).

## 5. Computed value: dependency, last resort

```hcl
dependency "apim" {
  config_path = "../apim"

  mock_outputs                            = { gateway_url = "https://mock.invalid" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  apim_gateway_url = dependency.apim.outputs.gateway_url
}
```

The producer adds an `outputs.tf`, and the consumer adds a `variables.tf` with
a typed `apim_gateway_url` variable. Never pass a secret this way.

Reaching for a `dependency` is a design signal. Either a lookup fits, or the
two units hand each other enough computed values that they belong in one unit.
That is why the AMBA resources and the AMBA policy share one unit.

## Cross-scope ids

A value from outside the unit's ancestor path, such as the connectivity
subscription id seen from a landing zone, is a literal local in `main.tf`:

```hcl
# Owned by platform/connectivity. Not an ancestor of this folder, so a literal.
connectivity_subscription_id = "00000000-0000-0000-0000-000000000000"
```
