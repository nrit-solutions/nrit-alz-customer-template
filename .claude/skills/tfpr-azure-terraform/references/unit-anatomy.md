# Unit anatomy

A unit is one folder, one Terraform root, one state file. This page covers
what goes in the folder and how its two files talk to the rest of the tree.
The house rules for the shape are in `AGENTS.md`, under **Authoring rules for
units**.

## Contents

- [The files](#the-files)
- [terragrunt.hcl](#terragrunthcl)
- [main.tf](#maintf)
- [local.context](#localcontext)
- [inputs](#inputs)
- [Dependency blocks](#dependency-blocks)
- [The lock file](#the-lock-file)
- [Where a unit lives](#where-a-unit-lives)

## The files

| File | Who writes it | Committed |
| --- | --- | --- |
| `terragrunt.hcl` | You | Yes |
| `main.tf` | You | Yes |
| `.terraform.lock.hcl` | `providers lock` | Yes |
| `outputs.tf` | You, only on a `dependency` producer | Yes |
| `variables.tf` | You, only on a `dependency` consumer | Yes |
| `lib/` | You, only to vendor a policy library, with a `README.md` | Yes |
| `backend.tf`, `providers.tf`, `context.tf` | `root.hcl`, at run time | Never |

The generated files carry resolved tenant and subscription ids. They are
gitignored, and the repository invariants hook fails a commit that tracks one.
A `versions.tf`, `locals.tf` or `data.tf` is not part of the shape: put that
content in `main.tf`.

## terragrunt.hcl

The common case is a header and an include:

```hcl
# network: the spoke VNet, its subnets and NSGs, and the hub peering.
# Providers: the root default set (azurerm, azapi, azuread).
# Own state because workloads in this landing zone change more often than the spoke.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependencies {
  paths = [
    "../../../../../platform/connectivity/westeurope/caf-connectivity-hub",
    "../../_global/lz-vending",
  ]
}
```

- The header says what the unit owns, which providers it needs, and why it has
  its own state. It is the one place a multi-line comment is expected.
- `expose = true` makes the root locals readable as
  `include.root.locals.<name>`. A provider override uses that.
- A unit never carries `terraform { source = ... }`. The Terraform code is the
  `main.tf` beside it.
- A unit that needs a different provider set declares its own
  `generate "provider"` and sets `merge_strategy = "deep"` on the include.
  Without it, the two same-named generate blocks are a hard error. The worked
  examples are `_foundation/landing-zones` and `_foundation/amba`. See
  [config-blocks.md](config-blocks.md#generate).

## main.tf

Plain Terraform that reads like any other root module. Order its content:

1. `locals`: the purpose, the name parts, the house tag block.
2. `data` sources, for values looked up by known name.
3. `ephemeral` blocks, for secrets read from Key Vault.
4. `module` calls to Azure Verified Modules.
5. Plain `resource` blocks, only where no AVM module fits.

Style rules for all of it are in [terraform-style.md](terraform-style.md).
[../templates/unit-main.tf](../templates/unit-main.tf) is the starting point.

## local.context

`root.hcl` writes `context.tf` into the unit, so `main.tf` reads the hierarchy
as plain Terraform:

| Key | Comes from |
| --- | --- |
| `tenant_id` | `tenant.hcl` |
| `tenant_root_id` | `customer.hcl`, else an all-zero placeholder |
| `business_unit` | `customer.hcl`, else `platform` |
| `amba_action_group_email` | `customer.hcl`, else a placeholder |
| `subscription_id` | the nearest `subscription.hcl` |
| `location`, `location_short` | the nearest `region.hcl` |
| `environment` | the nearest `env.hcl` |

It is the only supported way to read these values in `main.tf`. A value that
is not on an ancestor path, such as the connectivity subscription id seen from
a landing zone, is not in the context. Keep it as a literal local with a
comment naming its owner.

## inputs

Units normally take no `inputs`. The context replaces them. `inputs` appear
only to hand a `dependency` output to a declared variable:

```hcl
inputs = {
  apim_gateway_url = dependency.apim.outputs.gateway_url
}
```

Terragrunt passes each key as `TF_VAR_<key>`, so the consumer needs a matching
`variable` in `variables.tf`. An input with no matching variable is silently
ignored. `terragrunt hcl validate --inputs` catches that.

## Dependency blocks

Two blocks with similar names and different jobs:

| Block | Does | Costs |
| --- | --- | --- |
| `dependencies { paths = [...] }` | Orders apply. Reads nothing | Nothing |
| `dependency "<name>" { config_path = ... }` | Reads the producer's outputs | An output on the producer, a variable on the consumer, the value in the consumer's state |

Use `dependencies` for every unit that must exist first. Use `dependency` only
for a computed value with no stable name, after the lighter options in
[sharing-values.md](sharing-values.md) have failed. Every `dependency` with
`mock_outputs` also sets:

```hcl
mock_outputs_allowed_terraform_commands = ["validate", "plan"]
```

Without it, a mock value can reach an apply.

`projects.yml` sets `include_dependents: true`, so the engine re-plans the
dependents of a changed unit in the same PR, and `tfpr apply` runs them in
dependency order. A failed unit skips its dependents.

## The lock file

Each unit commits `.terraform.lock.hcl`, and it decides which provider
versions plan and apply use. Generate it with hashes for your machine and for
the runner:

```sh
terragrunt --working-dir live/<unit> init -backend=false
TG_NO_AUTO_INIT=true terragrunt --working-dir live/<unit> run -- providers lock -platform=darwin_arm64 -platform=linux_amd64
```

The rules for moving a provider version are in `AGENTS.md`, under **Version
pins**, and in
[Versions](https://docs.nrit.cloud/reference/versions/#provider-lock-files).

## Where a unit lives

```text
live/<management group>/<subscription>/<region or _global>/<unit>/
```

- One unit per thing that changes on its own schedule. Two resources that
  hand each other a computed value belong in the same unit.
- Region-agnostic work (subscription placement, budgets, RBAC) goes under
  `_global/`, which still carries a nominal `region.hcl`.
- The folder path is the state key. Moving or renaming a unit points it at an
  empty state, and the next plan creates everything again. Follow
  [Moving or renaming a unit](https://docs.nrit.cloud/operations/runbook/move-or-rename-a-unit/).

The layer files and the placement rules are in [hierarchy.md](hierarchy.md).
A worked example of a workload unit:
[Add a workload unit](https://docs.nrit.cloud/scenarios/options/add-a-workload-unit/).
