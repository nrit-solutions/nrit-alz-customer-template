---
name: terragrunt
description: >-
  Use when working with Terragrunt — authoring or reviewing terragrunt.hcl,
  root.hcl, or terragrunt.stack.hcl; scaffolding infrastructure-live / catalog
  repos, units, and Stacks; wiring remote_state, generate, dependency, include,
  and inputs blocks; running the Terragrunt 1.0 CLI (run --all, stack, scaffold,
  catalog, find, hcl fmt); keeping Terraform/OpenTofu DRY; or reviewing configs
  for deprecated CLI/flags and anti-patterns. Azure azurerm backend and ALZ/CAF
  focus, with a cloud-agnostic core.
---

# Terragrunt

Terragrunt is a thin orchestration wrapper around OpenTofu/Terraform that keeps
infrastructure code DRY, manages remote state and providers, and runs many
modules ("units") in dependency order.

This skill is **Azure-first** (azurerm backend, ALZ/CAF, Entra ID auth) but the
core patterns are cloud-agnostic. It covers three jobs: **scaffolding** new
setups, **answering** reference questions accurately, and **reviewing** existing
configs.

---

## ⚠️ Read first: Terragrunt 1.0 (shipped 2026-03-30)

Most pre-2025 knowledge — and a lot of blog content — is **wrong now**. Do not
emit any of the left-column forms.

| ❌ Deprecated / removed | ✅ Current (1.0) |
|---|---|
| `terragrunt apply-all` / `plan-all` / `destroy-all` / `output-all` | **removed** — use `run --all` |
| `terragrunt run-all <cmd>` | `terragrunt run --all <cmd>` (run-all is a deprecated alias) |
| `--terragrunt-non-interactive`, `--terragrunt-working-dir`, … | `--non-interactive`, `--working-dir` (prefix removed) |
| `TERRAGRUNT_*` env vars | `TG_*` (e.g. `TERRAGRUNT_TFPATH` → `TG_TF_PATH`) |
| root file named `terragrunt.hcl` | root file named **`root.hcl`**, referenced as `find_in_parent_folders("root.hcl")` |
| top-level `skip = true` | the **`exclude { … }`** block |
| top-level `retryable_errors` / `retry_*` | the **`errors { retry { … } }`** block |
| `terragrunt graph` / `graph-dependencies` | `run --graph` / `dag graph` |
| `hclfmt` / `hclvalidate` / `validate-inputs` | `hcl fmt` / `hcl validate` / `hcl validate --inputs` |
| `--queue-include-dir` / `--queue-exclude-dir` (7 flags) | the single **`--filter`** query language (old flags kept as aliases) |
| implicit passthrough of unknown tofu commands | none since v0.88 — use `terragrunt run -- <cmd>` (e.g. `run -- workspace ls`) |
| auto-bootstrap of the state backend | opt-in: `--backend-bootstrap` / `TG_BACKEND_BOOTSTRAP`, or `terragrunt backend bootstrap` |

Other current facts that surprise stale knowledge:
- **Stacks are GA** (since v0.78.0, May 2025) and recommended for new work.
- **Default tofu binary is `tofu`** since v0.57.12. Pin it explicitly with
  `terraform_binary` / `TG_TF_PATH` so behavior is deterministic. **This estate
  is Terraform** (azurerm), so templates pin `terraform_binary = "terraform"`;
  use `"tofu"` only for an OpenTofu estate.
- The old **`_envcommon` + multi-include** DRY pattern is "no longer
  recommended" — but it is still fully supported and extremely common in the
  wild. Don't rewrite existing repos to Stacks unasked.

When in doubt about a command, flag, block, or function, **read the matching
reference file below instead of answering from memory.** When the question is
version-sensitive or you're unsure, verify against `docs.terragrunt.com`.

---

## When to use this skill

Trigger on any of: `terragrunt`, `.hcl` Terragrunt configs, `root.hcl`,
`terragrunt.stack.hcl`, `infrastructure-live`, `infrastructure-catalog`,
units/stacks, `remote_state`/`generate`/`dependency`/`include` blocks, "keep
Terraform DRY", `run --all`, or migrating/reviewing Terragrunt code.

---

## House rules come first

This skill is generic Terragrunt knowledge. **If the repo you are working in has
an `AGENTS.md` (or `CLAUDE.md`/`CONTRIBUTING.md`), read it before applying any
default from this skill.** The repo decides its shape (catalog-pinned units vs
plain-TF units), its module-source policy, its naming convention, and its CI
flow. Never import the other shape into a repo that has chosen one.

## Mental model

- A **unit** is one directory containing a `terragrunt.hcl`. One Terraform root,
  one state file, the atomic deployable. A directory without a `terragrunt.hcl`
  is not a unit and is invisible to every tool that walks the tree.
- A **stack** is a group of units deployed together. Either *implicit* (a
  directory of units run with `run --all`) or *explicit* (a
  `terragrunt.stack.hcl` generating units into `.terragrunt-stack/`).

Two common repo shapes, both valid — the repo's own conventions pick one:

1. **Catalog + live.** Reusable, SemVer-tagged modules/units in a catalog repo;
   the live repo holds `.hcl` files whose `terraform { source }` pins
   `?ref=<tag>`. Promote code across environments by bumping the ref.
2. **Single repo, plain-TF units.** A unit is `terragrunt.hcl` **plus a
   `main.tf`** beside it that calls registry modules at an exact `version`. The
   `terragrunt.hcl` stays thin — an `include "root"`, optionally a
   `generate "provider"` override, optionally a `dependencies` block — and
   carries no `terraform { source }`.

---

## Discovery and CI: what makes a unit visible

Many CI systems for Terragrunt (comment-ops engines like Digger and its
lookalikes, Atlantis-style setups, custom pipelines) discover work by walking
the tree for `terragrunt.hcl` files, often via a config file such as
`projects.yml` or `atlantis.yaml` at the repo root.

**In such a repo, a folder with no `terragrunt.hcl` is invisible.** It is never
planned and never applied. Deliberate for placeholder folders — and a trap for
`terragrunt.stack.hcl`: a stack leaf has no `terragrunt.hcl`, so a PR adding one
can report zero impacted projects, pass every gate because there is nothing to
gate, and merge green having deployed nothing. No error appears anywhere.

So before introducing a stack leaf, confirm the repo's pipeline actually
understands stacks. Also check where ordering comes from: pipelines that walk
`dependencies` blocks lose a leaf that sits outside that graph.

## Stacks vs. classic include — which to use

Both are current Terragrunt (Stacks GA since v0.78.0). The repo's existing
conventions decide; for a genuinely green field:

| Consider **Stacks** (`terragrunt.stack.hcl`) when… | Consider **classic** (`root.hcl` + `include`) when… |
|---|---|
| You fan the same pattern across many envs/tenants/regions | Small or mostly-unique estate |
| Per-unit version pinning + atomic rollback matter | You want maximum explicitness, hand-edited leaves |
| Your CI understands stacks (see the discovery trap above) | CI discovers units by `terragrunt.hcl` |

`env.hcl` and `_envcommon/` are legacy: modern trees fold `environment` into
`region.hcl` and use neither. Keep them in mind only when reviewing an older
repo built that way, and do not rewrite such a repo unasked. Full Stacks detail:
`references/stacks.md`.

---

## Standard repo layouts

**ALZ/CAF example (plain-TF units).** Repo meta at the root; everything
deployable under `live/`. `root.hcl` sits at `live/root.hcl`, not at the repo
root. The tree mirrors the management-group hierarchy, and folder names are
management group IDs. A Stacks variant replaces each leaf pair with a
`terragrunt.stack.hcl`.

```
<repo>/
├── projects.yml                # CI discovery config (if the pipeline uses one)
├── mise.toml                   # pinned terraform + terragrunt
├── policy/                     # conftest policies (if a policy gate runs)
├── .github/workflows/          # the repo's CI entry points
└── live/
    ├── root.hcl                # remote_state + generate provider + generate context
    ├── tenant.hcl              # tenant_id + tenant_root_id (ancestor of everything)
    ├── _foundation/            # tenant governance, ABOVE any subscription or region
    │   ├── subscription.hcl    #   the management sub it is operated from
    │   ├── region.hcl          #   primary region
    │   ├── management-resources/  #  Log Analytics, DCRs, AMA identity
    │   │   ├── terragrunt.hcl
    │   │   └── main.tf
    │   ├── landing-zones/      #   MG hierarchy + policy + subscription placement
    │   │   ├── terragrunt.hcl  #     alz + azapi providers, merge_strategy = "deep"
    │   │   ├── main.tf
    │   │   └── lib/            #     vendored custom policy library
    │   └── amba/               #   Azure Monitor Baseline Alerts
    ├── platform/
    │   └── connectivity/       # MG = sub (collapsed: one sub in this MG)
    │       ├── subscription.hcl
    │       └── westeurope/
    │           ├── region.hcl  # location, location_short, environment
    │           └── caf-connectivity-hub/
    │               ├── terragrunt.hcl
    │               └── main.tf
    └── landingzones/
        └── corp/               # MG can hold >1 sub, so keep the sub level
            └── corp-workload/
                ├── subscription.hcl
                ├── _global/    # region-agnostic (placement, budgets, RBAC)
                │   ├── region.hcl   # nominal copy: root.hcl reads region.hcl always
                │   └── lz-vending/
                └── westeurope/
                    ├── region.hcl
                    └── network/
```

Two structural rules that are easy to get wrong:

- **The foundation sits above subscriptions and regions**, in `live/_foundation/`
  with its own `subscription.hcl` and `region.hcl`. It is operated *from* the
  management subscription but is not a workload of it, and it does not multiply
  per region. Do not nest it under `platform/management/<region>/`. It is three
  separate units, not one, so a change to monitoring does not re-plan policy.
- **The flattening rule.** A platform management group with exactly one
  subscription puts `subscription.hcl` directly in the MG folder, with no named
  subscription level. A landing-zone MG keeps the named subscription folder,
  because it can hold many.

Ready-to-copy versions of every file are in `templates/`.

**Reference links** (full list in `references/sources.md`):
- Official docs — Units https://docs.terragrunt.com/features/units/ ·
  Stacks https://docs.terragrunt.com/features/stacks/
- Gruntwork's catalog and live-stacks examples show the two-repo, `?ref=`-pinned
  shape. Useful background — but check the repo's own conventions before copying
  a leaf shape across.

---

## Workflow: scaffold a new setup

1. Confirm: cloud (default Azure/azurerm), repo shape (catalog-pinned vs
   plain-TF units — an existing repo's `AGENTS.md` decides), and the
   management group → subscription → region hierarchy.
2. **State backend first.** Azure azurerm auto-provisioning is still
   experimental, so pre-create the RG + Storage Account + container (a
   bootstrap repo or one-time script). See `references/azure.md`.
3. Copy `templates/root.hcl` to the root of the deployable tree (conventionally
   `live/root.hcl`), adapt the `remote_state`, `generate "provider"`, and
   `generate "context"` blocks (Azure variant in `references/azure.md`).
4. Add the hierarchy config files, each an ancestor of the units that read it:
   `templates/tenant.hcl` (at `live/`), `templates/subscription.hcl` (per sub),
   `templates/region.hcl` (per region, plus a nominal copy in each `_global/`).
   `templates/env.hcl` is legacy — only for repos with a distinct env level.
5. Add leaves: `templates/unit-terragrunt.hcl` (plain-TF shape pairs it with a
   `main.tf` calling registry modules at an exact `version`; catalog shape uses
   the `terraform { source }` variant inside it), or
   `templates/terragrunt.stack.hcl` where the pipeline understands Stacks.
6. Add `templates/gitignore` content. Pin `terraform_binary` and a version
   constraint in `root.hcl`, and the toolchain (`mise.toml` or similar).
7. Validate: `terragrunt hcl fmt`, `terraform fmt -recursive live/`, then per
   unit `terragrunt --working-dir live/<unit> init -backend=false` and
   `terragrunt --working-dir live/<unit> validate`. Against a live estate,
   plan/apply through the repo's CI flow, not from a shell.

## Sharing values between units

Each unit is its own state, so one unit cannot reference another's resources
directly. Take the **first option that fits**, in this order. The earlier ones
keep a unit at two files and add no coupling.

| You need | Use | Extra files |
|---|---|---|
| B to apply after A, no value crosses | `dependencies` (paths only) | none |
| A name you control | convention: derive the same name in both units | none |
| A live value with a known name | a `data` source lookup | none |
| A secret | Key Vault + `data` source | none |
| A computed value with no stable name | `dependency` block | producer output, consumer variable |

- `dependencies` (plural) is ordering only and reads nothing. `dependency`
  (singular) reads outputs. Do not use the second when you only need the first.
- **Never pass a secret through a `dependency` output.** It lands in both state
  files. Key Vault keeps it in one place and out of state.
- Every `dependency` with `mock_outputs` must set
  `mock_outputs_allowed_terraform_commands = ["validate", "plan"]`, or a mock can
  reach apply and deploy a wrong value.
- Reaching for a `dependency` is a design signal: either a lookup fits, or the
  two units are coupled enough that they belong in one unit.

## Workflow: answer a reference question

Don't answer Terragrunt API questions from memory — open the right file:
- CLI commands / flags / env vars / deprecations → `references/cli.md`
- HCL blocks (include, dependency, generate, remote_state, terraform, errors,
  exclude, feature, unit/stack) → `references/config-blocks.md`
- Built-in functions (`find_in_parent_folders`, `path_relative_to_include`,
  `read_terragrunt_config`, `sops_decrypt_file`, …) → `references/functions.md`
- Stacks (explicit/implicit, `values`, generation) → `references/stacks.md`
- DRY / dependencies / state / CI/CD / anti-patterns → `references/best-practices.md`
- azurerm backend, ALZ/CAF, auth, SOPS+Key Vault → `references/azure.md`
- Canonical source links → `references/sources.md`

## Workflow: review existing configs

Run through this checklist; cite `file:line`. Detail + rationale in
`references/best-practices.md`.

- [ ] **Deprecated CLI/flags** anywhere (scripts, CI, docs, Makefiles): `*-all`,
      `run-all`, `--terragrunt-*`, `TERRAGRUNT_*`, `hclfmt`, top-level `skip`/
      `retryable_errors`. → map to the 1.0 forms in the table above.
- [ ] **Root file** is `root.hcl` and referenced via
      `find_in_parent_folders("root.hcl")` (not bare).
- [ ] **`mock_outputs` footgun**: every `dependency` with mocks sets
      `mock_outputs_allowed_terraform_commands = ["validate", "plan"]` so mocks
      can never leak into `apply`.
- [ ] **Unit shape is consistent**: the repo's chosen shape (catalog-pinned
      `terraform { source }` vs plain-TF `main.tf` units) is not mixed ad hoc,
      and matches its `AGENTS.md` if it has one.
- [ ] **Version pinning**: catalog-style sources pin `?ref=<tag>` (never a
      branch); plain-TF modules pin an exact registry `version` (no `~>`), with
      `enable_telemetry = false` on AVM modules. `terraform_binary` and a
      version constraint are set in `root.hcl`.
- [ ] **Provider overrides**: a unit declaring its own `generate "provider"` sets
      `merge_strategy = "deep"` on its include, and the root block is left in
      place for every other unit.
- [ ] **Hierarchy values**: leaves read generated context or inherited inputs,
      never a hardcoded region, environment, or subscription id.
- [ ] **State isolation**: `key` uses `path_relative_to_include()` so each unit
      gets a unique state path.
- [ ] **Provider cache**: CI does NOT set `TF_PLUGIN_CACHE_DIR` with
      `run --all` (corruption) — use the Provider Cache Server instead.
- [ ] **DRY**: no copy-pasted backend/provider config in leaves; shared values
      live in `root.hcl` / hierarchy `.hcl` files / locals — not hardcoded.
- [ ] **Dependency graph**: shallow, acyclic, no over-granular units creating
      deep `run --all` chains; `dependency` (reads outputs) vs `dependencies`
      (ordering only) used correctly.
- [ ] **Secrets**: no plaintext secrets committed; `sops_decrypt_file` (KMS/Key
      Vault-backed) or runtime data sources used.
- [ ] **Azure**: `use_azuread_auth = true` (no storage keys); OIDC/workload
      identity in CI; correct `subscription_id` per provider.

---

## Templates index (`templates/`)

| File | Purpose |
|---|---|
| `root.hcl` | Root of the deployable tree (conventionally `live/root.hcl`): `remote_state` (backend coords via `get_env`) + `generate "provider"` + `generate "context"`; pins `terraform` (Azure + AWS variants inline) |
| `tenant.hcl` | Tenant-wide vars (`tenant_id`, `tenant_root_id`); repo root, ancestor of all deployables |
| `subscription.hcl` | Per-subscription/account vars (`subscription_id` via `get_env`; single source of truth for the sub id) |
| `region.hcl` | Per-region vars (`location`, `location_short`, `environment`); also co-located in each `_global/` |
| `env.hcl` | LEGACY per-environment vars; only for a repo with a distinct env level |
| `terragrunt.stack.hcl` | Explicit Stack composing units with `values`. Check the discovery trap before using in a `terragrunt.hcl`-discovered repo |
| `unit-terragrunt.hcl` | A leaf unit: plain-TF (pair with `main.tf`), provider-override, and catalog-source variants |
| `envcommon-component.hcl` | LEGACY classic per-component shared config; needs an `env.hcl` ancestor |
| `gitignore` | The Terragrunt entries to ignore |

## Reference index (`references/`)

`cli.md` · `config-blocks.md` · `functions.md` · `stacks.md` ·
`best-practices.md` · `azure.md` · `sources.md`
