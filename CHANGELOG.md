# Changelog

Per-client changelog. Records catalog and pipelines version bumps and when
new workloads are added.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Repository scaffold generated from `nrit-azure-customer-template`.
- `live/root.hcl` and `live/tenant.hcl`: the shared backend and locals contract.
  The backend reads the `BACKEND_*` Action variables at run time; units include
  root and generate their own providers from the exposed locals.
- `live/tenant/_global/caf-platform-foundation/`: the foundation deployment. Its
  `terragrunt.stack.hcl` wraps the catalog `caf-platform-foundation` stack at a
  pinned tag and supplies the customer-specific names and tags.
- Consumer workflows `plan.yml` and `apply.yml` calling the pinned
  `nrit-azure-pipelines` reusable workflows.
- `live/platform/connectivity/sub-connectivity/.../caf-connectivity-hub/`: the
  Virtual WAN hub. Its `terragrunt.stack.hcl` wraps the catalog
  `caf-connectivity-vwan` stack at `v0.2.0` and deploys into the connectivity
  subscription. The `plan` and `apply` workflows gained a `connectivity` job
  (apply runs after the foundation).
- `root.hcl` now reads the backend subscription from `AZURE_SUBSCRIPTION_ID`
  (the shared state account's subscription) rather than the per-folder deploy
  subscription, so cross-subscription deployments share the one backend.
- The `plan` and `apply` workflows pin the pipelines reusable workflows at
  `v0.1.1` and pass `catalog_app_id` plus the `catalog_app_private_key` secret,
  so the runner can clone the private catalog. ONBOARDING documents granting the
  pipelines and catalog repositories org-level Actions access.

### Changed

- The consumer workflows pin the pipelines reusable workflows at `v0.1.5`
  (clean, readable plan and apply output), up from `v0.1.3`. The bootstrap's
  `pipelines_ref` default matches, so a new customer pins the same tag.
- The foundation no longer auto-applies on push to main. It moved to a new
  manual `apply-foundation.yml` (`workflow_dispatch` only), so applying the ALZ
  management group hierarchy at tenant-root scope is always a deliberate action.
  `apply.yml` now triggers only on `live/platform/**` and applies the
  lower-scope connectivity workload; a change under `live/tenant/**` can no
  longer trigger an auto-apply. The OIDC contract is unchanged: both workflows
  still call `terragrunt-apply.yml@v0.1.3` through the `apply` environment.
