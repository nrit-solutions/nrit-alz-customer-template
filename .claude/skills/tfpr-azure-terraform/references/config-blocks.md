# Terragrunt blocks

The blocks a tfpr live repository uses, and how it uses them. The full list,
with every attribute, is at <https://docs.terragrunt.com/reference/hcl/blocks/>.

| Block | Where it appears here |
| --- | --- |
| `include` | Every unit |
| `locals` | `root.hcl` and the layer files |
| `generate` | `root.hcl`, and units that override the provider set |
| `remote_state` | `root.hcl` only |
| `dependencies` | Units that need another unit first |
| `dependency` | Rarely, for a computed value with no stable name |
| `inputs` | Only with a `dependency` |
| `errors`, `exclude`, `feature` | Available, not used by the template |
| `terraform { source }` | Not used: the code is the unit's `main.tf` |

## include

```hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}
```

- `expose = true` publishes the root's locals as `include.root.locals.<name>`.
- `merge_strategy` is `shallow` by default. The other values are `deep` and
  `no_merge`.
- One include per unit here. Multiple labeled includes belong to the
  `_envcommon` pattern, which this platform does not use.

## generate

Writes a file into the unit's run directory before Terraform runs.

```hcl
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azapi" {
      subscription_id = "${include.root.locals.subscription_id}"
      tenant_id       = "${include.root.locals.tenant_id}"
    }
  EOF
}
```

- `if_exists = "overwrite_terragrunt"` overwrites only files Terragrunt wrote,
  so a hand-written file of the same name is never clobbered silently.
- Use `<<-EOF`, which strips leading indentation, so the generated file stays
  readable.

**Overriding the root's block needs a deep merge.** A unit that declares its
own `generate "provider"` while including `root.hcl` under the default shallow
merge fails with:

```text
ERROR  Detected generate blocks with the same name: [provider]
```

Nothing is generated and the run stops. Add `merge_strategy = "deep"` to the
include and the unit's block replaces the root's. The docs page suggests a
child block should replace the parent's under any strategy. On Terragrunt 1.0
it does not, so keep the attribute. Never solve it by deleting the root block:
every other unit depends on it.

## remote_state

Lives in `root.hcl` only. The platform's block is in
[../templates/root.hcl](../templates/root.hcl), and the Azure detail in
[azure.md](azure.md#state-backend).

- `key = "${path_relative_to_include()}/terraform.tfstate"` gives every unit
  its own state, keyed by its path.
- `generate = { path = "backend.tf", ... }` writes the backend block. Do not
  add a separate `generate "backend"` for the same backend.
- Backend creation is opt-in in 1.0 and experimental for azurerm. The
  bootstrap creates the account instead.

## locals

```hcl
locals {
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  location    = local.region_vars.locals.location
}
```

Locals in a layer file are read by `root.hcl` through
`read_terragrunt_config`, as `<result>.locals.<name>`. A layer file holds only
a `locals` block.

## dependencies

```hcl
dependencies {
  paths = ["../network", "../../_global/lz-vending"]
}
```

Ordering only. Reads no values. Paths are relative to the unit's folder.

## dependency

```hcl
dependency "apim" {
  config_path = "../apim"

  mock_outputs                            = { gateway_url = "https://mock.invalid" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}
```

- Exposes the producer's outputs as `dependency.<name>.outputs.<key>`.
- `mock_outputs` are used only while the producer has no state yet.
  `mock_outputs_allowed_terraform_commands` keeps them out of apply. Both
  together, always.
- `skip_outputs = true` always uses the mocks and never reads state. It is
  rarely what you want.
- `mock_outputs_merge_strategy_with_state` merges mocks with partial real
  outputs (`no_merge`, `shallow`, `deep_map_only`).

When to use it at all: [sharing-values.md](sharing-values.md).

## inputs

```hcl
inputs = {
  apim_gateway_url = dependency.apim.outputs.gateway_url
}
```

Passed to Terraform as `TF_VAR_<key>`. Each key needs a declared variable.

## errors

Retry or ignore known errors. Replaces the removed top-level
`retryable_errors`.

```hcl
errors {
  retry "transient_azure" {
    retryable_errors   = [".*TooManyRequests.*", ".*RetryableError.*"]
    max_attempts       = 3
    sleep_interval_sec = 10
  }
}
```

`get_default_retryable_errors()` returns the built-in list to start from.

## exclude

Skips a unit for chosen actions. Replaces the removed top-level `skip`.

```hcl
exclude {
  if      = true
  actions = ["plan", "apply"]
}
```

The engine discovers units from `projects.yml`, so check how an excluded unit
behaves in a PR before relying on it. A placeholder folder with no
`terragrunt.hcl` is usually the simpler tool.

## feature

Runtime flags, set with `--feature <name>=<value>`.

```hcl
feature "diagnostics" {
  default = false
}
```

Not used by the template. The engine passes no feature flags, so in CI a flag
always takes its default.
