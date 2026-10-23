---
name: tfpr-azure-terraform
description: >-
  Units in an Azure infrastructure-live repository run by the tfpr PR engine:
  a unit's terragrunt.hcl and main.tf, root.hcl and the customer.hcl,
  tenant.hcl, subscription.hcl, env.hcl and region.hcl layers, Azure Verified
  Modules, sharing values or secrets between units, and the tfpr plan and apply
  flow. Also Terraform style for unit code and the Terragrunt 1.0 CLI. Use it
  to add, change or review a unit or a hierarchy file, or to answer a Terraform
  or Terragrunt question in such a repository, even when the request names
  neither tool.
---

# tfpr Azure Terraform

How to write and review units in an Azure live repository that the `tfpr`
engine plans and applies from pull request comments.

## Read AGENTS.md first

The repository's `AGENTS.md` holds the house rules. This skill is the how-to
and the reference behind them. When the two disagree, `AGENTS.md` wins, and the
repository's own files win over both: `mise.toml`, `projects.yml`, the workflow
files and each `main.tf` are the truth for pins.

Before any change, read these `AGENTS.md` sections: **Core concepts**,
**Authoring rules for units** (shape, modules, naming, tags, sharing values),
**Commands** (what never runs from a shell) and **Definition of done**.

## Mental model

- **The repository.** One Azure tenant. Everything deployable sits under
  `live/`, and folder names under `live/` are management group IDs. Below a
  management group: a subscription folder, a region folder, then units.
- **A unit** is a folder holding `terragrunt.hcl`. It is one Terraform root
  with its own state, keyed by its path. A folder without `terragrunt.hcl` is
  invisible: the engine never plans it.
- **The root contract.** Every unit includes `live/root.hcl`. The root
  generates `backend.tf`, `providers.tf` and `context.tf` into the unit at run
  time. Units never carry a backend or a default provider block.
- **The context.** `root.hcl` reads the nearest `customer.hcl`, `tenant.hcl`,
  `subscription.hcl`, `env.hcl` and `region.hcl` above the unit and writes them
  into `local.context`. Position in the tree is the wiring.
- **The engine.** `tfpr` discovers units from `projects.yml`, plans every
  impacted unit when a PR opens, and applies on a `tfpr apply` comment. Nobody
  applies from a shell. State is real, so a wrong state command is not undone
  by a revert.

## The unit contract

A unit is `terragrunt.hcl` plus `main.tf`, and a committed
`.terraform.lock.hcl`. Nothing else, unless a `dependency` block forces an
`outputs.tf` on the producer and a `variables.tf` on the consumer, or the unit
vendors a library under `lib/`.

| File | Holds |
| --- | --- |
| `terragrunt.hcl` | A short header comment, `include "root"`, and optional `dependencies`, `dependency` or provider override. No resources, no `terraform { source }` |
| `main.tf` | Plain Terraform. Locals, then data sources, then Azure Verified Module calls at an exact `version` with `enable_telemetry = false` |
| `.terraform.lock.hcl` | Provider hashes for your platform and `linux_amd64` |

Names and locations come from `local.context`. A unit never hardcodes a
region, an environment or its own subscription id. Detail:
[references/unit-anatomy.md](references/unit-anatomy.md).

## Workflow: add a unit

1. **Place it.** Pick the folder from the hierarchy: management group,
   subscription, region (or `_global`), unit name. Confirm a
   `subscription.hcl`, `env.hcl` and `region.hcl` exist above it.
   Done when the path matches the tree's existing pattern and all three layer
   files resolve from it. See
   [references/hierarchy.md](references/hierarchy.md).
2. **Write `terragrunt.hcl`** from
   [templates/unit-terragrunt.hcl](templates/unit-terragrunt.hcl). Fill the
   header: what the unit owns, its providers, why it has its own state. Add a
   `dependencies` path for every unit that must apply first.
3. **Write `main.tf`** from [templates/unit-main.tf](templates/unit-main.tf).
   Find the AVM module on the registry, pin its exact `version`, copy the house
   tag block, and build names in the CAF order from `local.context`. Follow
   [references/terraform-style.md](references/terraform-style.md).
4. **Choose how values cross units.** Take the first option that fits in
   [references/sharing-values.md](references/sharing-values.md). Done when every
   value from another unit is a derived name, a data source, an ephemeral Key
   Vault read, or a justified `dependency`.
5. **Run the local checks.** All of these pass:

   ```sh
   terragrunt hcl fmt
   terraform fmt -recursive live/
   pre-commit run --all-files
   terragrunt --working-dir live/<unit> init -backend=false
   TG_NO_AUTO_INIT=true terragrunt --working-dir live/<unit> validate
   TG_NO_AUTO_INIT=true terragrunt --working-dir live/<unit> run -- providers lock -platform=darwin_arm64 -platform=linux_amd64
   ```

6. **Open the PR.** Branch with a `feat/` or `fix/` prefix, add a line under
   `## [Unreleased]` in `CHANGELOG.md`, fill in the PR template with the
   impacted units and any pin that moved.
7. **Read the plan.** The engine plans every impacted unit and its dependents
   and posts a report comment. Read every create, delete and replace, and every
   gate row. Push a fix and the engine re-plans. Done when the plan shows only
   the intended changes and no gate row is red.
8. **Apply through the PR.** After the required review, a person with write
   access comments `tfpr apply`. Units apply in dependency order. Merge once
   `tfpr / merge-gate` is green. Posting `tfpr apply` is never yours to do
   unless the user asks in the same conversation.

Commands and flags: [tfpr command reference](https://docs.nrit.cloud/reference/commands/).
The run flow and cross-PR unit locks:
[Plan and apply](https://docs.nrit.cloud/operations/plan-and-apply/).

## Workflow: review a unit

1. Read `AGENTS.md`, then the diff, then the plan comment if one exists.
2. Walk [references/review-checklist.md](references/review-checklist.md) top
   to bottom. Every item gets a verdict: pass, finding, or not applicable.
3. Report each finding with `file:line`, the rule it breaks, and the fix.
   Order findings by risk: state loss and secrets first, then plan failures,
   then style.

Done when every checklist item has a verdict and every finding names its fix.

## Workflow: answer a reference question

Open the matching reference before answering. Terragrunt 1.0 renamed most
commands and flags, and the platform shape differs from most public examples,
so answers from memory are often wrong.

| Question about | Read |
| --- | --- |
| A unit's files, `local.context`, `inputs`, `dependency` | [unit-anatomy.md](references/unit-anatomy.md) |
| `root.hcl`, the layer files, where a value comes from | [hierarchy.md](references/hierarchy.md) |
| Moving a value or a secret between units | [sharing-values.md](references/sharing-values.md) |
| Backend, providers, AVM, azapi, provider registration | [azure.md](references/azure.md) |
| Terraform style: layout, naming, variables, `for_each`, secrets | [terraform-style.md](references/terraform-style.md) |
| A Terragrunt command, flag or environment variable | [terragrunt-cli.md](references/terragrunt-cli.md) |
| A Terragrunt block (`include`, `generate`, `errors`, ...) | [config-blocks.md](references/config-blocks.md) |
| A Terragrunt function | [functions.md](references/functions.md) |
| Catalog repositories, `?ref=` sources, Stacks, `_envcommon` | [other-shapes.md](references/other-shapes.md) |

For anything the references do not cover, check
<https://docs.terragrunt.com/> for Terragrunt, the Terraform registry for a
module's inputs, and Microsoft Learn for Azure behavior. Platform behavior is
documented at <https://docs.nrit.cloud/>.

## References

| File | Use it for |
| --- | --- |
| [references/unit-anatomy.md](references/unit-anatomy.md) | The two files of a unit, `local.context`, inputs, dependency blocks, lock files |
| [references/hierarchy.md](references/hierarchy.md) | The layer files, the root contract, placement rules |
| [references/sharing-values.md](references/sharing-values.md) | Convention, data sources, Key Vault with ephemeral reads, `dependency` |
| [references/azure.md](references/azure.md) | State backend, providers, AVM, azapi, provider registration |
| [references/terraform-style.md](references/terraform-style.md) | Terraform style for unit code, and the validation tools |
| [references/review-checklist.md](references/review-checklist.md) | The full review checklist |
| [references/terragrunt-cli.md](references/terragrunt-cli.md) | The Terragrunt 1.0 CLI and what it replaced |
| [references/config-blocks.md](references/config-blocks.md) | Terragrunt blocks as the platform uses them |
| [references/functions.md](references/functions.md) | Terragrunt functions as the platform uses them |
| [references/other-shapes.md](references/other-shapes.md) | Repository shapes this platform does not use |

## Templates

Copy, then replace every `<placeholder>`. All of them pass `terraform fmt` and
`terragrunt hcl fmt`.

| File | Goes to |
| --- | --- |
| [templates/unit-terragrunt.hcl](templates/unit-terragrunt.hcl) | `live/<...>/<unit>/terragrunt.hcl` |
| [templates/unit-main.tf](templates/unit-main.tf) | `live/<...>/<unit>/main.tf` |
| [templates/subscription.hcl](templates/subscription.hcl) | Each subscription folder, or a flattened management group folder |
| [templates/env.hcl](templates/env.hcl) | Each subscription folder, and each environment folder |
| [templates/region.hcl](templates/region.hcl) | Each region folder, and each `_global` folder |
| [templates/customer.hcl](templates/customer.hcl) | `live/customer.hcl`, once. The bootstrap normally writes it |
| [templates/root.hcl](templates/root.hcl) | `live/root.hcl`. The platform root contract, for reading or repair |
