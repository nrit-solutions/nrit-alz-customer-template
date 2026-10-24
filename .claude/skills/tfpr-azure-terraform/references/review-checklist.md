# Review checklist

Walk every item and give each a verdict: pass, finding, or not applicable.
Cite `file:line` for every finding, name the rule, and name the fix. Report
the highest-risk findings first: state loss and secrets, then plan failures,
then style.

Read `AGENTS.md` before you start. Where this list and `AGENTS.md` differ,
`AGENTS.md` wins.

## State and placement

- [ ] No unit was moved or renamed without the state-move procedure. The path
      is the state key, so a moved folder plans to recreate everything.
- [ ] No existing Azure resource is renamed to match a newer convention. A
      rename is a destroy and a create.
- [ ] The unit sits under the right management group, subscription and region
      folder, or under `_global/` if it is region-agnostic.
- [ ] A `subscription.hcl`, `env.hcl` and `region.hcl` resolve above it.
- [ ] No `terragrunt.stack.hcl`, and no folder with `.tf` files but no
      `terragrunt.hcl`. Discovery skips both, and the PR merges green having
      deployed nothing.
- [ ] A filled-in placeholder folder has its `README.md` updated.

## Unit shape

- [ ] Only `terragrunt.hcl`, `main.tf` and `.terraform.lock.hcl` are added,
      unless a `dependency` forced an `outputs.tf` or `variables.tf`, or the
      unit vendors a library under `lib/` with a `README.md`.
- [ ] No generated `backend.tf`, `providers.tf` or `context.tf`, no state, no
      plan output, no `.terraform/` or `.terragrunt-cache/`, no `.env`, `*.pem`,
      `*.key` or non-example `*.tfvars`.
- [ ] `terragrunt.hcl` opens with the header: what the unit owns, its
      providers, why it has its own state.
- [ ] `include "root"` uses `find_in_parent_folders("root.hcl")` and
      `expose = true`.
- [ ] No `terraform { source }` block.
- [ ] A provider override sets `merge_strategy = "deep"` on the include, and
      the root's default `generate "provider"` is untouched.

## Ordering and values

- [ ] Every unit that must exist first is in a `dependencies` path.
- [ ] Each value from another unit uses the lightest option that works:
      convention, then data source, then Key Vault, then `dependency`. A
      `dependency` is justified in the PR.
- [ ] Every `dependency` with `mock_outputs` sets
      `mock_outputs_allowed_terraform_commands = ["validate", "plan"]`.
- [ ] Every naming coupling with another unit is commented on both sides.
- [ ] Every literal id from outside the ancestor path names its owner.
- [ ] Values the `alz` provider reads are built from names, not outputs.

## Secrets

- [ ] No secret in `.tf`, `.hcl` or tfvars.
- [ ] Key Vault secrets are read with `ephemeral "azurerm_key_vault_secret"`
      into a `*_wo` argument, or resolved service-side. No plain
      `data "azurerm_key_vault_secret"`.
- [ ] No secret passes through a `dependency` output.
- [ ] Every `*_wo` argument has a `*_wo_version` that changes on rotation.
- [ ] Generated secrets use `ephemeral "random_password"`, not the resource.

## main.tf

- [ ] Content in order: `locals`, `data`, `ephemeral`, `module`, `resource`.
- [ ] Every registry module has an exact `version`. No `~>`, git or local
      source.
- [ ] Every AVM module sets `enable_telemetry = false`.
- [ ] No `provider`, `required_providers` or `backend` block.
- [ ] No hardcoded region, environment or own subscription id: all from
      `local.context`.
- [ ] Names follow the CAF order for where the unit lives, with CAF
      abbreviations (`log`, `id`, `afw`, `rg`, `vnet`, `kv`, `st`). Platform
      names carry no environment. Landing zone names do.
- [ ] Length-limited names fit: storage accounts and key vaults cap at 24
      characters.
- [ ] The house tag block is present, with values in the allowed lists, and a
      virtual network carries tags as well as its resource group.
- [ ] Repeated children use `for_each` over a map with stable keys. `count`
      only for on or off.
- [ ] A change from `count` to `for_each`, or a key change, ships with `moved`
      blocks.
- [ ] Labels are `snake_case`, name the role, and do not repeat the type.
- [ ] Variables and outputs, if present, have `type` and `description`, and
      secrets are not outputs.
- [ ] Event Grid event subscriptions use `azapi_resource`.
- [ ] A new resource namespace is registered for the target subscription,
      because no unit registers providers.
- [ ] Comments say why, in one line, and do not narrate the code.

## Pins

- [ ] A new unit ships `.terraform.lock.hcl` with `linux_amd64` hashes.
- [ ] One pin moves per PR, and the PR declares it.
- [ ] No lock file was deleted to make an error go away.
- [ ] Any `platform/alz` ref bump re-syncs the vendored architecture
      definition, and `amba` does not load `platform/alz`.

## Terragrunt and tooling

- [ ] No deprecated CLI anywhere: `run-all`, `*-all`, `--terragrunt-*`,
      `TERRAGRUNT_*`, `hclfmt`, a top-level `skip` or `retryable_errors`. Map
      each to its 1.0 form from [terragrunt-cli.md](terragrunt-cli.md).
- [ ] `pre-commit run --all-files` is clean.
- [ ] The offline `init -backend=false` and `validate` pass for every changed
      unit.

## The pull request

- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]`.
- [ ] The PR template lists every impacted unit and every moved pin.
- [ ] The plan was read in full: every create, delete and replace.
- [ ] Every gate row was read. A clean policy row was checked against a rule
      that could actually match, since an unmatched rule also reads clean.
- [ ] `tfpr / merge-gate` is green before merge.
