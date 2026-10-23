# Hierarchy and the root contract

The tree under `live/` mirrors the management group hierarchy. Five small
`.hcl` files carry scope, and `live/root.hcl` turns them into the context every
unit reads. The public pages are
[Live tree](https://docs.nrit.cloud/anatomy/live-tree/) and
[Root contract](https://docs.nrit.cloud/anatomy/root-contract/).

## Contents

- [The layer files](#the-layer-files)
- [How a value is found](#how-a-value-is-found)
- [Placement rules](#placement-rules)
- [An example tree](#an-example-tree)
- [root.hcl](#roothcl)
- [Validating offline](#validating-offline)

## The layer files

| File | Holds | Sits at | Written by |
| --- | --- | --- | --- |
| `customer.hcl` | `tenant_root_id`, the foundation `location` and `location_short`, `business_unit`, `amba_action_group_email` | `live/`, once | The bootstrap, once. The repository owns it after that |
| `tenant.hcl` | `tenant_id` | `live/`, once | Ships with the repository |
| `subscription.hcl` | `subscription_id` | Each subscription folder, a flattened platform management group folder, `_foundation/` | You |
| `env.hcl` | `environment`: `prod`, `staging` or `dev` | `_foundation/`, each platform subscription, each landing zone, each environment folder | You |
| `region.hcl` | `location`, `location_short` only | Each region folder, each `_global/` folder, `_foundation/` | You |

`tenant.hcl` is one value with a placeholder fallback:

```hcl
locals {
  tenant_id = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")
}
```

`subscription.hcl` takes the same `get_env` form only in `_foundation/`, which
runs in the management subscription. Everywhere else it holds the literal id
of that folder's subscription. Subscription, tenant and management group ids
are identifiers, not credentials, and are committed on purpose.

The foundation's `region.hcl` reads `location` and `location_short` from
`customer.hcl`, with West Europe as the fallback. Every other `region.hcl`
sets its own values.

Templates: [subscription.hcl](../templates/subscription.hcl),
[env.hcl](../templates/env.hcl), [region.hcl](../templates/region.hcl),
[customer.hcl](../templates/customer.hcl).

## How a value is found

`root.hcl` calls `find_in_parent_folders` from the including unit's folder, so
the nearest copy of each file above the unit wins. Three consequences:

- Every unit needs a `subscription.hcl`, an `env.hcl` and a `region.hcl` above
  it, plus `tenant.hcl` at `live/`. None of them has a fallback. A missing one
  fails the run for every unit beneath it.
- `customer.hcl` is the one optional layer. Without it, as in an unstamped
  template, `root.hcl` uses placeholders, and the landing-zones unit rejects
  the all-zero `tenant_root_id`, so an unstamped tree never deploys a
  hierarchy.
- Values on a sibling path are not visible. A landing zone cannot read the
  connectivity subscription from the tree. Keep such an id as a literal local
  in `main.tf`, with a comment naming its owner.

Short values only in `env.hcl` and `region.hcl`: they feed resource names, and
several Azure names cap at 24 characters.

## Placement rules

- **Folder names are management group IDs.** `live/` itself is the ALZ root.
  `_foundation/` is the one folder that is not a management group: it holds the
  tenant-wide units and is applied first.
- **The flattening rule.** A platform management group with exactly one
  subscription puts `subscription.hcl` and `env.hcl` directly in the management
  group folder. A landing zone management group keeps a named subscription
  folder, because it can hold many.
- **Subscription folder names** read `<archetype>-<purpose>-<environment>`, for
  example `corp-app-prod`. The folder is part of every state key below it.
- **Region-agnostic units** go in `_global/` with a nominal `region.hcl`.
- **Several environments in one subscription** add a folder per environment
  under the region folder, each with its own `env.hcl`. See
  [Several environments in one subscription](https://docs.nrit.cloud/scenarios/options/multiple-environments/).
- **A placeholder folder** has a `README.md` and no `terragrunt.hcl`. It costs
  nothing at plan time. When you fill it, update the README.

## An example tree

```text
live/
├── root.hcl
├── customer.hcl
├── tenant.hcl
├── _foundation/
│   ├── subscription.hcl
│   ├── env.hcl
│   ├── region.hcl
│   ├── management-resources/
│   ├── landing-zones/
│   └── amba/
├── platform/
│   └── connectivity/            # flattened: one subscription
│       ├── subscription.hcl
│       ├── env.hcl
│       └── westeurope/
│           ├── region.hcl
│           └── caf-connectivity-hub/
└── landingzones/
    └── corp/
        └── corp-app-prod/
            ├── subscription.hcl
            ├── env.hcl
            ├── _global/
            │   ├── region.hcl
            │   └── lz-vending/
            └── westeurope/
                ├── region.hcl
                ├── network/
                └── storage/
```

Copyable trees for every scenario are in the repository's `examples/` folder
and on [Scenarios](https://docs.nrit.cloud/scenarios/).

## root.hcl

[../templates/root.hcl](../templates/root.hcl) is the platform contract. It
does four things:

1. **Locals.** Reads `customer.hcl` with a fallback, then `tenant.hcl`,
   `subscription.hcl`, `region.hcl` and `env.hcl`, and flattens them into eight
   values.
2. **`generate "context"`.** Writes those values into the unit as
   `local.context`, one object so it cannot collide with a unit's own locals.
3. **`remote_state`.** The azurerm backend. The key is
   `${path_relative_to_include()}/terraform.tfstate`. The backend subscription
   comes from `AZURE_SUBSCRIPTION_ID`, because the state account lives in the
   management subscription while a unit may deploy elsewhere. Entra ID auth,
   no account keys.
4. **`generate "provider"`.** The default `azurerm`, `azapi` and `azuread`
   set, pinned to the unit's subscription and tenant, with provider
   registration turned off.

It closes with `terraform_binary = "terraform"` and the version floors.

Almost nothing in `root.hcl` is yours to edit. The backend names arrive from
the environment, and the customer values live in `customer.hcl`. Touch it only
to raise a version floor or add a provider to the default set, and expect that
change to re-plan every unit. Never delete the default `generate "provider"`
block to make one unit's override work: use the deep merge described in
[config-blocks.md](config-blocks.md#generate).

## Validating offline

Every coordinate has a placeholder, so any unit validates with no Azure
access. Terragrunt initializes before it validates, which would configure the
real backend, so run the pair in this order:

```sh
terragrunt --working-dir live/<unit> init -backend=false
TG_NO_AUTO_INIT=true terragrunt --working-dir live/<unit> validate
```

An error saying the modules are not installed means the init was skipped. Run
it. Do not drop the variable.
