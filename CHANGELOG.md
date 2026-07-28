# Changelog

Per-customer changelog for repositories generated from this template. Records
version bumps (AVM modules, the ALZ and AMBA library refs, the engine caller
pins) and when new workloads are added.

Template changes only reach repositories stamped after they merge. Each entry
therefore states whether existing customer repositories need the change
backported, or whether only new stamps get it.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- `AGENTS.md`, generic instructions for AI coding agents, identical in every
  repository built on this platform: the layout, the root contract and
  `local.context`, unit authoring rules (shape, provider overrides, module
  pinning, the CAF naming split, tags, sharing values between units), the
  comment-ops change flow, what is pinned where, the commands an agent may and
  may not run, and a definition of done. It carries no tenant values; anything
  specific to this repository stays in `README.md`, `ONBOARDING.md`, and the
  `live/` tree. `CLAUDE.md` is a one-line pointer at it.
- A changelog reminder workflow: CI warns, without failing, when a PR changes
  code but not this file. Backport: optional, only new stamps need it.

### Changed

- The engine caller pins moved from `v1.4.0` to `v1.5.0` and the
  `terraform-pr-ops.yml` caller added `closed` to its `pull_request` trigger
  types. This adopts cross-PR unit locks: the first PR to plan a unit owns it
  until that PR merges or closes, other PRs see a `locked` result, and
  `/unlock` force-releases. The `closed` trigger is what releases locks on
  merge. Backport: required for existing customer repositories; without the
  bump they have no locking, and a repository bumped without the `closed`
  type would strand locks until someone comments `/unlock`. The identities
  need Storage Table Data Contributor on the state account first, which the
  current nrit-alz-bootstrap applies.

### Fixed

- `tenant_root_id` is wired up. `live/_foundation/landing-zones/main.tf` sets
  `parent_resource_id` from `local.context.tenant_root_id` instead of the client
  config tenant id, so setting the value in `live/tenant.hcl` now actually places
  the hierarchy under an existing intermediate management group. Before this it
  was read by nothing and the hierarchy was always created at tenant root, with a
  clean plan and a clean apply either way. The default is unchanged: it resolves
  to the tenant id. A precondition on the unit's existing
  `azapi_client_config` data source fails the plan if the value is empty or still
  the all-zeros placeholder, which is what a missing `AZURE_TENANT_ID` produces,
  so a bad tenant id cannot silently become the hierarchy's parent. The guard
  adds nothing to state, so an applied estate still plans as a no-op.
- `docs/foundation-structure.md` lists the foundation leaves in deploy order
  (`management-resources`, then `landing-zones`, then `amba`), matching the deploy
  order section further down the same page.
- `live/platform/connectivity/README.md` includes the co-located `region.hcl` in
  its onboarding recipe. `root.hcl` reads a region unconditionally, so the unit
  failed without it.
- The first plan no longer needs a guess. `architecture_name` in
  `live/_foundation/landing-zones/main.tf` defaults to `nrit`, the only
  architecture the vendored library defines, and
  `connectivity_subscription_id` defaults to empty, which omits the connectivity
  entry from `subscription_placement` instead of sending a placeholder id a
  customer without a connectivity subscription cannot satisfy.

### Added

- ONBOARDING step 2 covers the two per-customer values it omitted: `environment`
  in `live/_foundation/region.hcl` (it feeds the `env` tag, and the tag policy
  allows prod, staging, and dev only) and `tenant_root_id` in `live/tenant.hcl`.
- ONBOARDING step 5 makes `.github/CODEOWNERS` and `LICENSE` explicit decisions.
  The CODEOWNERS team exists only in the NRIT organisation, so GitHub reports the
  file as invalid in the customer's; the licence is a self-declared placeholder
  that otherwise ships to the customer untouched.

### Changed

- `live/root.hcl` generates a `context.tf` into every unit, holding the hierarchy
  values as one `local.context` object (tenant, subscription, location,
  location_short, environment). The foundation units read `local.context` instead
  of hardcoding the region, so `live/_foundation/region.hcl` is the single source
  of truth and changing the region is a one-file edit. Same mechanism already used
  for `backend.tf` and `providers.tf`. Proven in `nrit-alz-live` first: the
  rollout there applied as a no-op across all ten units.
- Rebuilt the template to the current landing-zone design. The foundation is now
  three plain-Terraform `_foundation` units (`management-resources`,
  `landing-zones`, `amba`), each a `main.tf` plus `terragrunt.hcl` with its own
  state, replacing the previous `terragrunt.stack.hcl` catalog-stack layout. The
  four `nrit-azure-pipelines` consumer workflows are replaced by two
  `nrit-tf-pr-ops` reusable-workflow callers (`terraform-pr-ops.yml`, `drift.yml`),
  pinned `@v1` with `engine_ref: v1` and `secrets: inherit`. Plan and apply now run
  from pull request comments (comment-ops); the foundation applies through the same
  flow in dependency order rather than a separate manual dispatch. The bootstrap
  moved to `nrit-alz-bootstrap`; README, ONBOARDING, and the docs are rewritten for
  the reusable-workflow model.
