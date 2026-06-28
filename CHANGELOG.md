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
