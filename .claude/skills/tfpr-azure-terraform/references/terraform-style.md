# Terraform style for units

How Terraform code in a unit should look. It applies to `main.tf`, and to the
`variables.tf` and `outputs.tf` that a `dependency` sometimes forces. The
house rules in `AGENTS.md` sit on top of this page and win where they differ.

## Contents

- [Files inside a unit](#files-inside-a-unit)
- [Formatting](#formatting)
- [Order inside a block](#order-inside-a-block)
- [Naming](#naming)
- [Locals](#locals)
- [Variables](#variables)
- [Outputs](#outputs)
- [for_each and count](#for_each-and-count)
- [Versions and providers](#versions-and-providers)
- [Secrets: ephemeral values and write-only arguments](#secrets-ephemeral-values-and-write-only-arguments)
- [Comments](#comments)
- [Validation tools](#validation-tools)

## Files inside a unit

Everything lives in `main.tf`, in this order: `locals`, `data`, `ephemeral`,
`module`, `resource`. One file per unit keeps a reviewer on one page, and the
generated `context.tf`, `providers.tf` and `backend.tf` cover what other
layouts split into `versions.tf` or `providers.tf`.

Split only when a `dependency` forces it:

- `outputs.tf` on the producer, holding just the outputs a consumer reads.
- `variables.tf` on the consumer, holding just the variables its `inputs` set.

When `main.tf` grows past what one reviewer can follow, the unit is probably
two units. Split by change cadence, not by resource type.

## Formatting

`terraform fmt` decides the layout, and the pre-commit hook enforces it. Do not
fight it. What it does, so you write close to it the first time:

- Two spaces per indent level, no tabs.
- In a run of consecutive single-line arguments, the `=` signs line up. A blank
  line or a nested block starts a new run.
- One blank line between top-level blocks.

`.hcl` files follow the same rules through `terragrunt hcl fmt`.

```sh
terraform fmt -recursive live/
terragrunt hcl fmt
```

## Order inside a block

Put the arguments a reader needs first at the top, and lifecycle concerns at
the bottom. Separate each group with one blank line.

1. Meta-arguments that change what the block is: `source` and `version` on a
   module, then `for_each` or `count`, then `provider`.
2. Plain arguments, required ones first. Identity before configuration:
   `name`, `location`, `parent_id` or `resource_group_name`, then the rest.
3. `enable_telemetry` and `tags`, last among the arguments.
4. Nested blocks.
5. `lifecycle`, then `depends_on`.

```hcl
module "key_vault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "<exact version>"

  name                = "kv-app-${local.context.environment}-${local.context.location_short}"
  location            = local.context.location
  resource_group_name = module.resource_group.name
  tenant_id           = local.context.tenant_id
  sku_name            = "standard"

  public_network_access_enabled = false
  purge_protection_enabled      = true

  enable_telemetry = false
  tags             = local.tags
}
```

## Naming

Two kinds of name, two sets of rules.

**Terraform labels** (the second string on a block, local and variable names):

- `snake_case`, lowercase, words separated by underscores.
- Name the role, not the type. The type is already on the block:
  `resource "azurerm_subnet" "workload"`, not `"workload_subnet"` or
  `"subnet_workload"`.
- Use `this` for the only instance of its type in the unit.
- Module labels describe what the module builds for this unit: `module "hub"`,
  `module "resource_group"`, `module "storage"`.
- Booleans read as a state: `public_access_enabled`, not `public_access`.
- Plural names for maps and lists: `subnets`, `role_assignments`.

**Azure resource names** follow the CAF component order and the CAF
abbreviations, built from `local.context`. The rule and the length exceptions
are in `AGENTS.md`, under **Naming**. Build each name once, in `locals` or in
the argument, never by string surgery on another resource's name.

```hcl
locals {
  name_suffix = "app-${local.context.environment}-${local.context.location_short}"
}

# rg-app-prod-weu, vnet-app-prod-weu, kv-app-prod-weu
```

## Locals

- Compute a value once and give it a name when it is used twice, or when the
  expression needs a name to be readable.
- Keep the house tag block in `locals.tags` and pass it to every module.
- Prefer a flat map of named values over one deeply nested object.
- A local that couples to another unit's naming carries a one-line comment
  naming that unit.

## Variables

A unit declares variables only to receive `dependency` outputs. When it does:

- Always set `type`, as tight as the value allows. Prefer an `object({...})`
  over `any`.
- Always set `description`, saying what the value is and where it comes from.
- Add a `validation` block when a wrong value would deploy rather than fail,
  and make the `error_message` name the fix.
- Set `sensitive = true` on anything secret. It hides the value from plan
  output. It does not keep it out of state.
- Leave `default` off, so a missing input fails at plan instead of deploying a
  guess.
- `nullable = false` when null would mean nothing sensible.

```hcl
variable "hub_firewall_private_ip" {
  type        = string
  description = "Private IP of the hub firewall, from the connectivity hub unit's output."
  nullable    = false

  validation {
    condition     = can(cidrhost("${var.hub_firewall_private_ip}/32", 0))
    error_message = "hub_firewall_private_ip must be an IPv4 address. Check the hub unit's outputs."
  }
}
```

## Outputs

A unit declares outputs only when another unit reads them through a
`dependency`. Keep them to what that consumer reads.

- Always set `description`.
- Output ids and names, not whole resource objects. A whole object couples the
  consumer to every attribute and puts all of it in the consumer's state.
- `sensitive = true` where it applies, but a secret should not be an output at
  all. Use Key Vault, as in [sharing-values.md](sharing-values.md).

```hcl
output "gateway_url" {
  description = "Gateway URL of the APIM instance, read by the app unit."
  value       = module.apim.gateway_url
}
```

## for_each and count

Use `for_each` over a map with stable, meaningful keys for anything that has
more than one instance. Each instance's address then carries its key, so
adding or removing one entry touches only that entry.

```hcl
locals {
  subnets = {
    workload = { address_prefixes = ["10.20.1.0/26"] }
    data     = { address_prefixes = ["10.20.1.64/26"] }
  }
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                 = "snet-app-${each.key}-${local.context.environment}-${local.context.location_short}"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.vnet.name
  address_prefixes     = each.value.address_prefixes
}
```

With `count` over a list, removing the first item shifts every later index, and
the plan destroys and recreates resources that did not change. Keep `count`
for the on-or-off case:

```hcl
resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostics_enabled ? 1 : 0
  # ...
}
```

Changing a block from `count` to `for_each`, or changing its keys, changes
every address. Add `moved` blocks in the same PR, and read the plan for
replacements.

Most AVM modules already take maps for their repeated children
(`private_endpoints`, `role_assignments`, `subnets`). Use the module's map
before reaching for `for_each` on the module itself.

## Versions and providers

- **Modules:** an exact `version` on every registry module. No `~>`, no git
  source, no local path. tflint fails anything else.
- **Providers:** the `~>` constraints live in the `generate "provider"` block
  of `root.hcl` or of an overriding unit. The committed `.terraform.lock.hcl`
  is the real pin. Move one pin per PR.
- **Terraform and Terragrunt:** pinned in `mise.toml`, with floors in
  `root.hcl`. A unit sets neither.
- **No provider configuration in a unit.** No `provider` block, no
  `required_providers`, no `terraform { backend }`. The root generates them.
  A unit with a genuinely different provider set overrides the whole
  `generate "provider"` block with a deep-merged include, as the foundation's
  `landing-zones` and `amba` units do.

## Secrets: ephemeral values and write-only arguments

A secret must not reach the plan or the state. Three Terraform features make
that possible:

- An **`ephemeral` block** (Terraform 1.10 or later) reads or generates a value
  that exists only during the run. It is never written to plan or state.
- A **write-only argument** (Terraform 1.11 or later), named `*_wo`, accepts an
  ephemeral value and sends it to Azure without storing it. Its partner
  `*_wo_version` is a plain number you bump to send a new value.
- An ephemeral value can only flow into another ephemeral context, a
  write-only argument, or a provider block. Terraform refuses to put it in an
  ordinary argument.

Reading a secret from Key Vault:

```hcl
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

Generating a secret and storing it in Key Vault without it touching state:

```hcl
ephemeral "random_password" "sql_admin" {
  length  = 32
  special = true
}

resource "azurerm_key_vault_secret" "sql_admin" {
  name             = "sql-admin-password"
  key_vault_id     = module.key_vault.resource_id
  value_wo         = ephemeral.random_password.sql_admin.result
  value_wo_version = 1
}
```

`random` is not in the default provider set. Terraform installs
`hashicorp/random` on init, so regenerate the lock file after adding it.

Check the provider docs for the pinned version before relying on a `*_wo`
argument: not every resource has one yet. Where none exists, prefer a
service-side Key Vault reference over a plain data source.

Things that look safe and are not:

- `sensitive = true` hides a value in output but stores it in state.
- `data "azurerm_key_vault_secret"` stores the secret value in state.
- A plain `random_password` resource stores its result in state.

## Comments

A comment says why, when the code cannot. One line where you can.

- The `terragrunt.hcl` header is the one expected multi-line comment: what the
  unit owns, its providers, why it has its own state.
- Comment every naming coupling with another unit, on both sides.
- Comment every literal id from outside the unit's ancestor path with its
  owner.
- Do not narrate the code. `# create the resource group` above
  `module "resource_group"` adds nothing.

## Validation tools

What runs, and where. The pre-commit hooks and the PR's `pre-commit` job run
the same set, so a skipped local hook fails in CI and stops the plan.

| Tool | Checks | Runs |
| --- | --- | --- |
| `terraform fmt`, `terragrunt hcl fmt` | Layout | Commit and PR |
| `tflint` (`.tflint.hcl`) | The recommended ruleset, plus exact module versions. The required-providers rules are off because the root generates providers | Commit and PR |
| `checkov` (`.checkov.yaml`) | Static checks on the module calls only. `CKV_TF_1` is skipped because registry sources carry no commit hash | Commit and PR |
| Repository invariants | Generated files, state, plan output and secret files tracked by mistake, stack files, Terraform outside a unit, engine pins | Commit and PR |
| `terragrunt validate`, offline | Types, references, required arguments | Locally, with `init -backend=false` first |
| conftest, checkov, infracost | Policy, security and cost against the real plan, where modules have expanded | Every plan, as `post_plan` hooks |

```sh
pre-commit run --all-files
terragrunt --working-dir live/<unit> init -backend=false
TG_NO_AUTO_INIT=true terragrunt --working-dir live/<unit> validate
```

The plan-time gates are described on
[Gates](https://docs.nrit.cloud/operations/gates/), and the hook model on
[Hook and step model](https://docs.nrit.cloud/reference/hooks/).

The review checklist that pulls all of this together is
[review-checklist.md](review-checklist.md).
