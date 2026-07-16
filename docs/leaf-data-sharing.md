# Sharing data and ordering between leaves

Each leaf is its own Terraform root with its own state (see the plain-Terraform
foundation under `live/_foundation/`).
Separate state is what gives us small blast radius, but it also means one leaf
cannot reference another leaf's resources directly. This is how to order leaves
and move values between them, and how to choose the lightest option each time.

## Two Terragrunt blocks, do not confuse them

- **`dependencies`** (plural): ordering only. It lists paths that must apply
  first. It reads no values. Use it when leaf B must run after leaf A but does
  not need anything A computed.
- **`dependency`** (singular): data. It reads another leaf's remote-state
  outputs and exposes them as `dependency.<name>.outputs.<x>`. Use it only when
  you actually need a value A produced.

Our foundation uses `dependencies` for the apply order
(`management-resources` then `landing-zones` then `amba`) and needs no `dependency` block,
because the only things that cross are predictable names, not computed values.

## Choosing how to share a value: take the first that fits

Work down this list. The earlier options keep a leaf as just `main.tf` plus
`terragrunt.hcl` and add no coupling.

### 1. Convention: derive the same name in both leaves

Best for names you control and can predict. The producer creates the resource
with a derived name; the consumer rebuilds the same name and, if it needs the
id, constructs it. Nothing crosses state.

```hcl
# management-resources leaf creates it
resource_group_name = "rg-management-${local.location_short}"

# landing-zones leaf references it by convention (must stay in sync)
management_providers_scope = "/subscriptions/${local.management_subscription_id}/resourceGroups/rg-management-${local.location_short}/providers"
```

Cost: the two leaves share a naming rule that must not drift. Comment the
coupling on both sides.

### 2. Data source: look up a live value by its known name

Best for a value Azure computes that you cannot predict but can query, when you
already know the resource's name. This stays inside the consuming leaf's
`main.tf`, adds no `dependency`, and does not couple to the other leaf's state.

```hcl
# get the AMA identity's principal id without touching the producer's state
data "azurerm_user_assigned_identity" "ama" {
  name                = "uami-management-ama-${local.location_short}"
  resource_group_name = "rg-management-${local.location_short}"
}
# data.azurerm_user_assigned_identity.ama.principal_id
```

Cost: the consumer applies after the producer (add a `dependencies` path so the
resource exists when the data source reads it).

### 3. Key Vault: for secrets

Best for an APIM key, a connection string, or any secret. The producing leaf
writes the secret to Key Vault; the consuming leaf reads it with a data source.

```hcl
data "azurerm_key_vault_secret" "apim_key" {
  name         = "apim-primary-key"
  key_vault_id = data.azurerm_key_vault.platform.id
}
```

Do not pass a secret through a `dependency` output. That writes the secret into
both state files. Key Vault keeps it in one place and out of Terraform state.

### 4. Terragrunt `dependency`: computed value, last resort

Use only when the value is genuinely computed and cannot be looked up (for
example a generated id with no stable name). It reads the producer's
remote-state outputs.

```hcl
# consumer terragrunt.hcl
dependency "apim" {
  config_path = "../apim"

  # so plan works before the producer is applied. Mocks must never reach apply.
  mock_outputs                            = { gateway_url = "https://mock" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  apim_gateway_url = dependency.apim.outputs.gateway_url
}
```

Cost, and where the two-file minimalism ends:

- The **producer** must expose the value as an `output` (it needs an
  `outputs.tf`).
- The **consumer** must declare a `variable` to receive the input (it needs a
  `variables.tf`), and the value is written into the consumer's state.
- The producer must be applied before the consumer, or the mock is used for
  plan. Always set `mock_outputs_allowed_terraform_commands = ["validate",
  "plan"]` so a mock can never leak into an apply.

## The design principle

Put leaf boundaries where only static or convention data crosses. Keep two
things that hand each other a computed value in the **same** leaf. That is why
the AMBA resources and the AMBA policy share one leaf: the policy needs the
identity the resources create, so a plain `module.amba_resources` reference in
one state is simpler and safer than a cross-state `dependency`.

When you find yourself reaching for a `dependency` between two leaves, treat it
as a signal: either a data-source lookup or Key Vault fits, or those two leaves
are coupled enough that they belong together.

## Decision table

| You need | Use | Extra files |
|---|---|---|
| B to apply after A, no value | `dependencies` (paths) | none |
| A name you control | convention (same derived name) | none |
| A live value with a known name | `data` source | none |
| A secret | Key Vault + `data` source | none |
| A computed value with no stable name | `dependency` block | producer output, consumer variable |

## Anti-patterns

- Secrets through `dependency` outputs. They land in both states. Use Key Vault.
- A `dependency` where a `data` source would do. It couples state and forces
  apply order you may not need.
- Deep `dependency` chains. They make `run --all` slow and fragile. Prefer flat
  graphs and lookups.
- Reading outputs when you only need ordering. Use `dependencies`, not
  `dependency`.
- A `dependency` with mocks but no `mock_outputs_allowed_terraform_commands`.
  The mock can then reach apply and deploy wrong values.

## Why this matters

- **WAF Operational Excellence**: lookups and Key Vault keep leaves small and
  independent, so most changes touch one leaf and one plan.
- **WAF Reliability**: fewer cross-state links means a smaller blast radius and
  a shallower `run --all` graph.
- **WAF Security**: secrets stay in Key Vault, not in Terraform state or plan
  output.
