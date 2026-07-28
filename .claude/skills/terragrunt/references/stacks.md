# Terragrunt Stacks

Stacks reached GA in v0.78.0 (May 2025) and are stable in 1.0. A **stack** is a
collection of units deployed together. Canonical:
`docs.terragrunt.com/features/stacks/`.

## Two flavors

### Implicit stacks
No special file — a stack is just a directory tree of units. `terragrunt run --all`
discovers every `terragrunt.hcl`, builds the DAG from `dependency`/`dependencies`,
and runs in order. Best for a small number of unique units and maximum
explicitness. This is what the **classic** repo layout uses.

### Explicit stacks (`terragrunt.stack.hcl`)
A file of `unit` (and nested `stack`) blocks that **generate** units at runtime
into a `.terragrunt-stack/` directory. Best for fanning the same pattern across
many environments/tenants/regions, with per-unit version pinning. This is what
the **modern** (live-stacks) layout uses. Canonical examples: live + Stacks —
https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example ;
the catalog the stacks source their units from —
https://github.com/gruntwork-io/terragrunt-infrastructure-catalog-example .

## The `terragrunt.stack.hcl` file

```hcl
locals {
  name = "platform"
}

unit "vnet" {
  source = "github.com/org/infrastructure-catalog//units/vnet?ref=v1.4.0"
  path   = "vnet"                       # where it's rendered under .terragrunt-stack/
  values = {
    name          = "${local.name}-vnet"
    address_space = ["10.10.0.0/16"]
  }
}

unit "key_vault" {
  source = "github.com/org/infrastructure-catalog//units/key-vault?ref=v1.4.0"
  path   = "key-vault"
  values = {
    name     = "${local.name}-kv"
    vnet_path = "../vnet"               # relative dependency wiring (consumed inside the unit)
  }
}

# Nest another stack for reuse / multi-env fan-out
stack "monitoring" {
  source = "github.com/org/infrastructure-catalog//stacks/monitoring?ref=v1.4.0"
  path   = "monitoring"
  values = { environment = "prod" }
}
```

### `unit` block attributes
- `source` (required) — Git/HTTPS/local source of the **unit** (a dir containing
  a `terragrunt.hcl`). **Use a Git URL even intra-repo** — units render into
  shallow dirs and can't see sibling paths.
- `path` (required) — render location under `.terragrunt-stack/`.
- `values` — typed inputs exposed inside the generated unit as `values.<key>`.
- `no_dot_terragrunt_stack` — render outside `.terragrunt-stack/`.
- `no_validation` — skip validation of generated config.

### `stack` block
Same attributes; generates a nested `terragrunt.stack.hcl`. Parent `values`
propagate down into nested stacks.

## How `values` flow

In the **unit's** own `terragrunt.hcl` (lives in the catalog), read them as
`values.<key>` and map to module `inputs`:

```hcl
# units/vnet/terragrunt.hcl  (in the catalog repo)
include "root" { path = find_in_parent_folders("root.hcl") }

terraform {
  source = "${get_repo_root()}//modules/vnet?ref=${try(values.version, "v1.4.0")}"
}

dependency "rg" {
  config_path  = values.rg_path
  mock_outputs = { name = "mock-rg" }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  name           = values.name
  address_space  = values.address_space
  resource_group = dependency.rg.outputs.name
}
```

## Constraints (important)
- `include` is **not supported** inside `terragrunt.stack.hcl`.
- Dependencies **cannot be declared on `stack` blocks** — only between units
  (via `values` paths → `dependency` inside the unit).
- A directory can't be both a unit and a stack (`terragrunt.hcl` and
  `terragrunt.stack.hcl` are mutually exclusive in one dir).
- `.terragrunt-stack/` is **generated** — git-ignore it, never hand-edit it.

## Commands
```bash
terragrunt stack generate          # render .terragrunt-stack/ (inspect before running)
terragrunt stack run plan          # generate + plan all units
terragrunt stack run apply
terragrunt stack output            # read outputs
terragrunt stack clean             # remove generated dirs
```

## Why Stacks over the classic include pattern
- **Per-unit version pinning + atomic rollback.** Each env can pin a different
  unit version, so you promote dev→stage→prod by bumping a ref, and roll back the
  same way.
- Eliminates copy-pasted `_envcommon`/include boilerplate (officially "no longer
  recommended", though still supported).
- Real-world report at 1.0: ~20k lines of IaC removed, plan time 2h → 8min
  (with the provider cache).

## When NOT to use Stacks
- Existing classic repo that works — don't migrate unasked.
- Small, mostly-unique estate where one file per component is clearer.
- Team unfamiliar with the generated-units indirection.
