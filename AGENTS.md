# AGENTS.md

Instructions for AI coding agents working in this repository. Humans should read
`README.md` first; this file is the same picture written for an agent, with the
rules that are easy to get wrong made explicit.

This file is generic and identical across every repository built on this
platform. It describes the shape and the standards, never one tenant's values.
Anything specific to this repository lives in the files it points at:
`README.md`, `ONBOARDING.md`, `CHANGELOG.md`, and the `live/` tree itself.

## What this repository is

An infrastructure-live repository for one Azure tenant. It holds Terragrunt
configuration for a Cloud Adoption Framework (CAF) landing zone under `live/`,
and it is operated by the `nrit-tf-pr-ops` comment-ops engine, consumed as a
pinned reusable GitHub Actions workflow.

Two things drive most of the rules below:

1. **You never apply infrastructure from a shell.** Plan and apply happen in CI,
   triggered by pull request comments. There are no local credentials for it and
   no push-to-main apply.
2. **State is real.** This tree manages a live tenant. A wrong `terraform state`
   or `az` command is not recoverable by reverting a commit.

Each repository owns its own version pins. Upgrades arrive as deliberate,
reviewed commits, never automatically.

## Read these before changing anything

In-repo, in this order:

| File | What it tells you |
| --- | --- |
| `README.md` | The shape of this repository and its change flow |
| `ONBOARDING.md` | Every value to set for this tenant, and the required repo configuration |
| `docs/foundation-structure.md` | Why `_foundation/` sits above subscriptions, and the multi-region decision |
| `docs/leaf-data-sharing.md` | How units share values and ordering. Read before adding any cross-unit reference |
| `docs/policy-gates.md` | The conftest, checkov, and infracost gates |
| `docs/upgrade-guide.md` | What is pinned and how to move a pin |
| `docs/operations-runbook.md` | Teardown ordering and AMBA remediation |

Public platform documentation (Material for MkDocs): <https://docs.nrit.cloud/>

| Page | Use it for |
| --- | --- |
| [Repository anatomy](https://docs.nrit.cloud/anatomy/) | The live tree, the root contract, the foundation units, the policy library |
| [Growing the tree](https://docs.nrit.cloud/operations/growing-the-tree/) | Adding a connectivity hub, a landing zone, or a unit. The flattening rule |
| [Plan and apply](https://docs.nrit.cloud/operations/plan-and-apply/) | The run flow, dependency-ordered apply, cross-PR unit locks |
| [Gates](https://docs.nrit.cloud/operations/gates/) | Policy, security, and cost gates |
| [Azure Policy](https://docs.nrit.cloud/policy/) | Customizing assignments, enforcement strategy, testing a policy change |
| [Command reference](https://docs.nrit.cloud/reference/commands/) | Every comment command and what it posts |
| [projects.yml schema](https://docs.nrit.cloud/reference/projects-yml/) | Discovery and hook configuration |
| [Versions and upgrades](https://docs.nrit.cloud/reference/versions/) | The version statement for the platform |
| [Troubleshooting](https://docs.nrit.cloud/reference/troubleshooting/) | Failure modes and their fixes |

The docs site describes the platform as the template ships it. This repository
owns its own pins, so read a pin from the file that owns it. Prose in older
documents can be stale; the workflow files, `main.tf` files, and `mise.toml` are
the truth.

## Layout

```
<repo>/
├── AGENTS.md, README.md, ONBOARDING.md, CHANGELOG.md, LICENSE
├── mise.toml                    # pinned terraform + terragrunt versions
├── projects.yml                 # engine discovery config and post-plan gate hooks
├── policy/                      # active conftest policies (the policy gate)
├── examples/policy/             # example rego, not executed
├── docs/                        # the documents listed above
├── .github/workflows/           # thin callers into the nrit-tf-pr-ops engine
└── live/                        # everything deployable
    ├── root.hcl                 # backend, providers, and the locals contract
    ├── tenant.hcl               # tenant id + root management group id
    ├── _foundation/             # tenant-wide governance, applied first
    │   ├── management-resources/#   Log Analytics, DCRs, AMA identity
    │   ├── landing-zones/       #   MG hierarchy, base policy, subscription placement
    │   │   └── lib/             #   vendored ALZ policy library
    │   └── amba/                #   Azure Monitor Baseline Alerts
    ├── platform/                # connectivity, identity, management, security
    ├── landingzones/            # corp, online, local
    ├── sandbox/                 # Sandbox MG
    └── decommissioned/          # Decommissioned MG
```

Folder names under `live/` are management group IDs. The tree mirrors the CAF
hierarchy: management group, then a subscription folder, then a region folder,
then units.

A management group folder with no `terragrunt.hcl` beneath it is a placeholder.
It documents the shape of the estate before the resources exist, costs nothing
at plan time, and is filled in when the tenant needs it. Follow
[Growing the tree](https://docs.nrit.cloud/operations/growing-the-tree/), and
keep the folder's README accurate afterwards.

## Core concepts

**Unit.** A folder containing `terragrunt.hcl`. It is one Terraform root with its
own state. A folder without `terragrunt.hcl` is invisible to discovery. The
engine's word for a unit is "project", and the label is the path, for example
`live/platform/connectivity/westeurope/caf-connectivity-hub`.

Never add a `terragrunt.stack.hcl` here. A stack leaf has no `terragrunt.hcl`,
so discovery skips it entirely: the PR plans nothing, every gate passes with
nothing to gate, and it can merge green having deployed nothing.

**The root contract.** Every unit does
`include "root" { path = find_in_parent_folders("root.hcl"), expose = true }`.
`live/root.hcl` then generates three files into the unit at run time:

| Generated file | Holds |
| --- | --- |
| `backend.tf` | The azurerm backend. Entra ID auth, no account keys. State key is the path |
| `providers.tf` | Default `azurerm` + `azapi`, pinned to the unit's subscription and tenant |
| `context.tf` | `local.context`, the hierarchy values |

`local.context` is the only supported way to read hierarchy values in `main.tf`:
`tenant_id`, `tenant_root_id`, `subscription_id`, `location`, `location_short`,
`environment`.

**The hierarchy files.** `tenant.hcl` sits at `live/`, and `subscription.hcl` and
`region.hcl` sit at the level they describe. `find_in_parent_folders` only walks
ancestors, so every unit must have all three above it. A region-agnostic unit
still needs a `region.hcl`, which is why `_global/` folders carry one.

**Offline by design.** Every coordinate falls back to a placeholder through
`get_env`, so the tree generates and validates with no Azure access.

## Making a change

1. Branch from `main`. Use a `feat/`, `fix/`, `chore/`, or `docs/` prefix.
2. Edit units. Run the local checks below.
3. Update `CHANGELOG.md` under `## [Unreleased]`. CI warns, without failing, when
   a PR changes code and not the changelog. Skip it only for changes invisible to
   an operator.
4. Open a PR. Fill in `.github/pull_request_template.md` honestly, especially the
   list of impacted units and any pin that moved.
5. The engine plans every impacted unit automatically and posts a run comment.
   `include_dependents: true` in `projects.yml` means dependents are planned too.
6. Read the whole plan. Every delete and every replace. Read the gate panel.
7. Satisfy whatever review this repository requires, then comment `/apply`. Units
   apply in dependency order. A failed unit skips its dependents rather than
   applying them against stale outputs.
8. Merge once `tf-pr-ops / merge-gate` is green.

Comment commands: `/plan`, `/plan -p <label>`, `/apply`, `/apply -p <label>`,
`/unlock`. The engine reacts to your comment: 👀 seen, 🚀 running, 🎉 done, 👎
failed.

The first PR to plan a unit holds a cross-PR lock on it until that PR merges or
closes. Another PR touching the same unit gets a `🔒 Locked by another PR`
report. That is expected behaviour, not a bug. `/unlock` on the owning PR
force-releases.

**Approvals.** `/apply` is gated on this repository's required reviews, read from
GitHub's review decision. A repository that deliberately requires no approvals
opts back in with the `TF_PR_OPS_ALLOW_UNREVIEWED_APPLY` variable; that is only
appropriate for a single-writer repository, where the plan review is the gate.
Check the repository's ruleset and that variable to know which applies here, and
never set it to work around a review that is failing.

If this repository is itself a GitHub template, the engine skips it: its own pull
requests run no plans, and review is by eye.

Expect a first foundation apply to take sixty to ninety minutes, because of
policy propagation.

## Authoring rules for units

**Shape.** A unit is `terragrunt.hcl` plus `main.tf`, and nothing else, unless a
Terragrunt `dependency` forces an `outputs.tf` on the producer and a
`variables.tf` on the consumer. Do not add `variables.tf`, `outputs.tf`,
`versions.tf`, `providers.tf`, or `backend.tf` speculatively. The last two are
generated and gitignored.

**`terragrunt.hcl` carries the comment header.** Every unit starts with a short
block saying what the unit owns, which providers it needs, and why it has its own
state. Match that style.

**Overriding providers.** A unit that needs a provider set other than
`azurerm` + `azapi` declares its own `generate "provider"` and must set
`merge_strategy = "deep"` on its include. Without the deep merge, two same-named
generate blocks are a hard error and nothing is generated.
`_foundation/landing-zones` and `_foundation/amba` are the worked examples.

**Modules.** Source public Azure Verified Modules from the registry, with an
explicit exact `version`. No `~>` on a module version, no git sources, no local
module directories. Set `enable_telemetry = false`. There is no private module
catalog: every unit sources a public module directly, and the only custom content
is the policy library vendored under `live/_foundation/landing-zones/lib/`.

**Naming.** Follow the Cloud Adoption Framework component order. Whether the name
carries an environment depends on where the unit sits in the tree.

```
Platform, under _foundation/ and platform/
  <type abbreviation>-<purpose>-<region>[-<instance>]
  "${abbrev}-${purpose}-${local.context.location_short}"

Landing zones, under landingzones/
  <type abbreviation>-<purpose>-<environment>-<region>[-<instance>]
  "${abbrev}-${purpose}-${local.context.environment}-${local.context.location_short}"
```

| Unit lives under | Name | Why |
| --- | --- | --- |
| `_foundation/` | `rg-management-weu`, `law-management-weu`, `uami-management-ama-weu`, `dcr-change-tracking-weu`, `rg-amba-weu` | Tenant singletons. One hierarchy, one workspace, one AMBA deployment, serving every environment in the tenant |
| `platform/` | `rg-hub-weu`, `vnet-hub-weu` | Platform shared services. The hub carries traffic for prod, dev, and sandbox spokes alike |
| `landingzones/` | `rg-corp-network-prod-weu`, `vnet-corp-prod-weu`, `snet-workload-prod-weu`, `nsg-corp-workload-prod-weu` | A landing zone belongs to exactly one environment |

The rule behind the split: environment is a property of the workload, not of the
platform. There will never be a non-production management workspace, so
`law-management-prod-weu` would imply a sibling that cannot exist. CAF names its
shared resources the same way, for example `vnet-shared-eastus2-001`.

The instance suffix (`001`) is optional everywhere: add it when a second resource
of the same type, purpose, and region is plausible, and leave it off otherwise.
Decide it once, at creation. Azure resource names cannot be changed, so a
resource that starts without a number can never gain one. For the same reason,
**never rename an existing resource to match a newer convention**: renaming a
resource group destroys and recreates it and everything inside it. Expect a
mature tenant to be mixed, and leave the old names alone.

Never hardcode a region or an environment in a unit. Both come from
`local.context`, which `region.hcl` feeds. `Azure/naming/azurerm` is available
where a generated name is acceptable.

Two length exceptions to know. Resource types that allow no hyphens and cap at 24
characters, storage accounts and key vaults, compress to
`st<purpose><env><loc><instance>`. Resource types with a tight limit need
checking against
[the naming rules](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules)
before you commit to a long purpose. Everything the foundation creates today
sits at roughly half its limit.

Reference:
[Define your naming convention](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
and
[resource abbreviations](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).

**Tags.** Two different things, and they are easy to confuse.

What policy requires. The `Enforce-Tag-Gov` assignment (the vendored
`Enforce-Tag-Governance` set) does three things, all shipping as `Audit`:

| Rule | Tags |
| --- | --- |
| Mandatory, on resource groups only | `app`, `opsteam`, `criticality`, `confidentiality` |
| Value must be in the allowed list | `criticality` (`mission-critical`, `medium`, `low`), `confidentiality` (`public`, `private`, `confidential`, `restricted`), `env` (`prod`, `staging`, `dev`) |
| Inherited onto resources when missing | `app`, `opsteam`, `criticality`, `confidentiality` from the resource group; `businessunit`, `env`, `costcenter` from the subscription |

What the code does on top. The foundation and platform units set a house tag
block: `businessunit`, `env`, `costcenter`, `app`, `opsteam`, `criticality`,
`confidentiality`, `managed-by`. Only the first seven are read by policy.
`managed-by` is convention alone. Copy the block when you add a unit, and keep
the values inside the allowed lists above.

Set tags explicitly on a virtual network as well as on its resource group. The
inherit rules above copy them down at run time, so a VNet with no tags in code
drifts on every plan.

The AMBA resource group is the documented exception: AMBA remediation restamps
it, so Terraform leaves its tags unmanaged.

**Sharing values between units.** Take the first option that fits, in this order:

1. Convention. Derive the same name in both units. Comment the coupling on both
   sides.
2. A `data` source lookup by known name.
3. Key Vault plus a `data` source, for anything secret.
4. A Terragrunt `dependency` block, only for a computed value with no stable
   name. It costs an output on the producer, a variable on the consumer, and it
   writes the value into the consumer's state.

Use `dependencies` (plural, paths only) when you need ordering and no value. Use
`dependency` (singular) only for data. Never pass a secret through a `dependency`
output: it lands in two state files. Any `dependency` with `mock_outputs` must
also set `mock_outputs_allowed_terraform_commands = ["validate", "plan"]`.

**Plan-time known values.** The `alz` provider reads data sources at plan time and
cannot accept unknown values. That is why `_foundation/landing-zones` computes
policy default value IDs from names instead of reading resource attributes. Keep
it that way.

**Preconditions over silent defaults.** Where an unset environment value would
change what gets deployed rather than fail, add a `lifecycle` precondition with a
message that names the fix. `_foundation/landing-zones/main.tf` guards
`tenant_root_id` this way.

**Azure Policy changes.** Adjust assignments through
`policy_assignments_to_modify` in `live/_foundation/landing-zones/main.tf`. That
file carries commented reference blocks for the common customizations and for the
recommended production hardening. Lift what you need out of them, merging by
management group key. Do not enforce a wave of guardrails in one commit: follow
the enforcement strategy on the docs site, scope the first wave with
`resource_selectors`, validate compliance, then widen.

**Comments.** Only where the reason is not obvious from the code. Comment the
why, not the what. Keep it to one line where you can. The existing longer headers
on `root.hcl` and unit `terragrunt.hcl` files are deliberate exceptions.

## Commands

Safe to run locally:

```sh
mise install                                            # the pinned toolchain
terragrunt hcl fmt                                      # format HCL
terraform fmt -recursive live/                          # format Terraform
cd live && terragrunt find --json --dependencies --dag  # what discovery sees
terragrunt --working-dir live/<unit> init -backend=false
terragrunt --working-dir live/<unit> validate
conftest test <plan.json> -p policy/                    # if you have a plan JSON
```

Never run, in this repository, without an explicit instruction from the user in
the same conversation:

- `terraform apply`, `terragrunt apply`, `run --all apply`, or any `destroy`
- `terraform init` with a real backend, `terraform state`, `import`, `taint`, or
  `force-unlock`
- any `az` command that writes, including policy remediation and role assignment
- `git push --force`, or any push to `main`
- `gh workflow run`, `gh pr merge`, or posting `/apply` on someone's behalf

Reading is fine: `az account show`, `gh pr view`, `gh run view`. Confirm the
active identities first: `az` must be signed in to the tenant this repository
deploys to, and `gh` must be the account that should be acting here.

## Version pins

| What | Pinned in | Rule |
| --- | --- | --- |
| Terraform, Terragrunt | `mise.toml` | The engine auto-detects it. No workflow edit needed |
| The engine | both files in `.github/workflows/` | The `uses:` ref and `engine_ref` must match, in `terraform-pr-ops.yml` and `drift.yml` |
| AVM modules | each unit's `main.tf` | Exact `version` |
| ALZ and AMBA libraries | `library_references` in the two foundation `terragrunt.hcl` files | Keep the `platform/alz` ref identical in both |
| Providers | the `generate "provider"` blocks | `~>` constraints are fine here |

Engine tags are immutable `vX.Y.Z`. There is no moving `v1` tag, so an upgrade is
always a commit here. Bump the `uses:` ref and `engine_ref` together: `engine_ref`
picks the scripts and `uses:` picks the workflow YAML, and a skew runs new YAML
against old scripts.

Move one pin per PR so the plan diff stays readable. After bumping the
`platform/alz` ref, re-sync
`lib/architecture_definitions/*.alz_architecture_definition.json` against the
stock architecture at the new version and keep the custom tag archetype on the
intermediate root. Nothing automates that. See
`live/_foundation/landing-zones/lib/README.md`.

`docs/reference/versions.md` on the public docs site is the version statement for
the platform as the template ships it. Do not create a competing version table in
this repository.

## Gates

Three checks run as `post_plan` hooks on every plan and every drift plan. They
are configured in `projects.yml` and their scripts live in the engine, resolved
through `$TFPR_ENGINE_DIR`.

| Gate | Tool | Config | Default |
| --- | --- | --- | --- |
| Policy | conftest | `policy/governance.rego` | Advisory, `warn` rules only |
| Security | checkov | `CHECKOV_SOFT_FAIL=1` in `projects.yml` | Advisory |
| Cost | infracost | engine script, needs `INFRACOST_API_KEY` | Informational, always exits 0 |

To enforce policy, add a `deny` rule. To enforce security, drop
`CHECKOV_SOFT_FAIL`. Do that deliberately, after triaging the report-only
findings, never as a side effect of another change.

## Security and data handling

- No secrets in the tree. Not in `.tf`, not in `.hcl`, not in tfvars. Secrets are
  GitHub repository secrets, or Key Vault plus a `data` source.
- Subscription IDs, tenant IDs, and management group IDs are committed on
  purpose. They are identifiers, not credentials. Do not "fix" them.
- Never commit state, plan files, `.terraform/`, `.terragrunt-cache/`, or the
  generated `backend.tf`, `providers.tf`, `context.tf`. They are gitignored.
- Authentication is Entra workload identity OIDC through the `plan` and `apply`
  GitHub environments. Do not add a client secret or a storage account key
  anywhere, and do not change the environment names: the federated credential
  subjects embed them.
- infracost sends region and SKU to a hosted pricing API. That is an accepted,
  documented trade-off. Do not add any other tool that sends repository content
  off-platform.
- Do not name other tenants or customers in this repository.

## Definition of done

- [ ] HCL and Terraform formatted
- [ ] `init -backend=false` and `validate` pass for every changed unit
- [ ] Only `terragrunt.hcl` and `main.tf` added, unless a `dependency` required more
- [ ] Every module version is exact, and `enable_telemetry = false`
- [ ] No hardcoded region, and names derive from `local.context`
- [ ] Ordering expressed with `dependencies`, data crossing justified per the list above
- [ ] A filled-in placeholder folder has its README updated to match
- [ ] `CHANGELOG.md` updated under `[Unreleased]`
- [ ] PR template filled in, impacted units listed, pins declared
- [ ] Plan read in full, including deletes and replaces, and the gate panel read
- [ ] `tf-pr-ops / merge-gate` green before merge

## Why this shape (CAF and WAF)

- **Operational Excellence**: one management group hierarchy, one policy set, one
  workspace. Every change is a reviewed pull request with a plan attached.
- **Reliability**: one unit is one state, so blast radius stays small. Adding a
  region touches connectivity and workloads, never the governance layer.
- **Security**: OIDC workload identity, no long-lived cloud secret, Entra ID auth
  to state, secrets in Key Vault rather than state or plan output.
- **Cost Optimization**: a single central Log Analytics workspace, and a cost
  estimate on every plan.

## External references

- [Azure Verified Modules](https://azure.github.io/Azure-Verified-Modules/)
- [Terraform Registry, AVM modules](https://registry.terraform.io/namespaces/Azure)
- [Azure Landing Zones Terraform accelerator](https://azure.github.io/Azure-Landing-Zones/accelerator/)
- [ALZ Library](https://azure.github.io/Azure-Landing-Zones-Library/)
- [Azure Monitor Baseline Alerts](https://azure.github.io/azure-monitor-baseline-alerts/)
- [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/)
- [Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/)
- [Azure Policy](https://learn.microsoft.com/azure/governance/policy/overview)
- [Terragrunt documentation](https://docs.terragrunt.com/)
- [Terraform language](https://developer.hashicorp.com/terraform/language)
- [HashiCorp Terraform style guide](https://developer.hashicorp.com/terraform/language/style)
- [conftest](https://www.conftest.dev/) and [Rego](https://www.openpolicyagent.org/docs/policy-language)
- [checkov](https://www.checkov.io/) and [infracost](https://www.infracost.io/docs/)
- [mise](https://mise.jdx.dev/)
