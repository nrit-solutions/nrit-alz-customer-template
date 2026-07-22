# Changelog

Per-customer changelog for repositories generated from this template. Records
version bumps (catalog, AVM modules, the engine caller pins) and when new
workloads are added.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
