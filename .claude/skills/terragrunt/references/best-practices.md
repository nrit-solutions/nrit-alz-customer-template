# Terragrunt best practices, anti-patterns & CI/CD

Sourced from `docs.terragrunt.com` + the Gruntwork blog. Distinguishes official
guidance from community opinion where it matters.

## DRY & repo structure

- **Two valid repo shapes; the repo's `AGENTS.md` (if present) decides.**
  1. *Catalog + live*: reusable, SemVer-tagged units in a catalog repo; the live
     repo's `terraform { source }` pins `?ref=<tag>`. Gruntwork's examples show
     this (catalog —
     https://github.com/gruntwork-io/terragrunt-infrastructure-catalog-example ;
     live + Stacks —
     https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example ).
  2. *Single repo, plain-TF units*: each unit is `terragrunt.hcl` plus a
     `main.tf` calling registry modules at an exact `version`; no
     `terraform { source }` block anywhere.
  Do not mix the two in one tree, and do not migrate a repo between them unasked.
- **One `root.hcl`**, at the root of the deployable tree (conventionally
  `live/root.hcl`; repo meta stays outside it). It holds the shared
  `remote_state` and `generate` blocks. Leaves do
  `include "root" { path = find_in_parent_folders("root.hcl"), expose = true }`.
- **Remote state DRY:** define the backend once; `key =
  "${path_relative_to_include()}/terraform.tfstate"` makes each unit unique.
- **Provider DRY:** `generate "provider"` in `root.hcl` writes `providers.tf` into
  every unit.
- **Hierarchy vars:** `tenant.hcl` (repo root), `subscription.hcl` (or
  `account.hcl`), `region.hcl`, and (legacy classic) `env.hcl`, loaded with
  `read_terragrunt_config(find_in_parent_folders(...))`. The current tree folds
  `environment` into `region.hcl`, not a separate `env.hcl` layer.
- **"Large modules are harmful."** Organize by environment + small cohesive
  components (`vnet`, `key-vault`, `app`), not monoliths — but don't go so
  granular that the dependency graph gets deep.
- The `_envcommon` + multi-include pattern is **"no longer recommended"** by the
  docs (Stacks supersede it) but is still fully supported and common. Don't
  rip it out of working repos unasked.

## Dependencies

- `dependency` reads outputs (`dependency.x.outputs.y`); `dependencies` only
  orders `run --all`. Use the right one.
- **Mock-output safety:** always
  `mock_outputs_allowed_terraform_commands = ["validate", "plan"]`. Without it,
  mock values can be silently applied. Mocks are for CI/plan/validate, not apply.
- `skip_outputs = true` ("always use mocks if set") ≠ `mock_outputs` ("use mocks
  only when real outputs are unavailable"). Don't combine carelessly.
- Keep the graph **shallow and acyclic** — circular deps are rejected; deep
  graphs slow the run queue, widen blast radius, and make ordering fragile.

## State management

- Two mutually-exclusive mechanisms: the `remote_state` block (config + optional
  auto-provision) vs a `generate "backend"` block (config only). Don't use both
  for one backend.
- **1.0:** backend bootstrap is opt-in (`--backend-bootstrap` /
  `TG_BACKEND_BOOTSTRAP` / `terragrunt backend bootstrap`).
- **Fine vs coarse state:** fine-grained (one state per small unit) = smaller
  blast radius, faster parallel plans, but more `dependency` wiring. Coarse =
  fewer deps but slow plans, big blast radius, lock contention. Terragrunt leans
  fine-grained.

## `run --all` hazards

- `run --all plan` **fails if dependencies were never deployed** (no state to read
  outputs from) unless `mock_outputs` exist.
- `apply`/`destroy` auto-add `-auto-approve` — pass `--no-auto-approve` for
  interactive safety. **`destroy` runs in reverse DAG order.**
- `--queue-ignore-dag-order` runs units concurrently ignoring dependencies —
  dangerous for stateful ops.
- Prefer scoped runs: plan one unit, or use `--filter` to target changed units.

## OpenTofu vs Terraform

- Default binary is `tofu` since v0.57.12 — this silently switched some
  `terraform`-based workflows. **Pin explicitly:** `terraform_binary = "tofu"`
  (or `"terraform"`) and a version constraint. Or set `TG_TF_PATH`.
- OpenTofu stays MPL-2.0 (open source); Terraform is BSL-1.1 since Aug 2023.

## Version pinning

- Catalog shape: every `terraform { source }` / `unit { source }` pins
  `?ref=<tag>`, never a branch or `main`. Plain-TF shape: pin the module in
  `main.tf` with an exact registry `version` (no `~>`), and pin any provider
  library refs (e.g. the `alz` provider's `library_references`).
- Pin the tofu/terraform version too; state-file schemas aren't guaranteed stable
  across versions (matters when reading state outputs via `dependency`).

## Secrets

- Native `sops_decrypt_file()` (no `run_cmd` wrapper). Back SOPS with a cloud KMS
  / **Azure Key Vault**, not just age/GPG, for access control + audit. Declare
  rules once in `.sops.yaml`.
- Commit only the encrypted file. In CI, supply the decryption key via OIDC /
  workload identity to the KMS (no static secret), or a masked CI secret.
- Alternatively pull secrets at runtime via data sources to avoid storing them in
  state.

## Provider cache (perf)

- **Do NOT set `TF_PLUGIN_CACHE_DIR` with `run --all`** — concurrent writes
  corrupt the cache. Use Terragrunt's built-in **Provider Cache Server**
  (`TG_PROVIDER_CACHE=1`). OpenTofu ≥1.10 also gets an auto-configured shared
  cache.

## CI/CD

- **Comment-ops repos come first.** Some repos are driven by a comment-ops
  engine (Digger, or an in-house equivalent): plan runs on the PR, apply is a
  `/apply` comment, discovery and gates live in a config file like
  `projects.yml`, and a merge-gate status blocks unapplied PRs. Such a repo
  documents its flow in its `AGENTS.md` — follow it, and never run an apply
  from a shell there.
- **Run only affected units** on PRs: `terragrunt run --all --filter
  '[main...HEAD]...' -- plan` (changed units + their dependents).
  `--filter-affected` is the shorthand for the diff part.
- **Discovery:** `terragrunt find --dag --json` to enumerate units in order;
  `terragrunt dag graph` to visualize.
- **Official action:** `gruntwork-io/terragrunt-action` installs + runs Terragrunt
  in GitHub Actions.
- **Run Queue** is the built-in ordering/concurrency engine: `--parallelism`,
  `--queue-ignore-errors`.
- **Gruntwork Pipelines** is Gruntwork's GitOps CI/CD purpose-built for
  Terragrunt (native Stacks support); they position it over Atlantis (vendor
  bias — Atlantis works but is widely reported as heavy/slow with Terragrunt).

## Top anti-patterns to flag in review

1. Deprecated CLI/flags/env (`*-all`, `run-all`, `--terragrunt-*`, `TERRAGRUNT_*`,
   `hclfmt`, top-level `skip`/`retryable_errors`).
2. Root file still named `terragrunt.hcl`, or bare `find_in_parent_folders()`.
3. `mock_outputs` without `mock_outputs_allowed_terraform_commands`.
4. Unpinned module `version` (a `~>` range, a branch, or a git source instead of
   an exact registry version); unpinned binary.
5. Copy-pasted backend/provider config in leaves instead of `root.hcl`.
6. Hardcoded values that belong in hierarchy `.hcl` files / locals / inputs.
7. `TF_PLUGIN_CACHE_DIR` + `run --all`.
8. Over-granular units → deep dependency graphs; or mega-modules.
9. Plaintext secrets in repo or state.
10. (Azure) storage account keys instead of `use_azuread_auth`; static SP secret
    instead of OIDC in CI.
