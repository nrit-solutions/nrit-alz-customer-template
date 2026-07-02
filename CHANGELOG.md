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

- Enable the Azure Monitor Baseline Alerts (AMBA) platform baseline by pinning
  the catalog at `v0.4.1`. The foundation stack now sets `amba_action_group_email`
  (a required onboarding value, placeholder `alerts@example.com`) and the AMBA
  resource names. ONBOARDING gains the email in step 2, the
  `Microsoft.PolicyInsights` registration in step 5, and a post-apply remediation
  step (step 8); AMBA policies are assigned by the apply but the alerts and action
  group deploy only via remediation.
- The connectivity hub and foundation management resource names now follow the
  ALZ accelerator convention: short region geo-code, no sequence number, no
  customer prefix (`rg-vwan-hub-weu`, `vwan-hub-weu`, `vhub-hub-weu`,
  `fw-hub-weu`, `fwp-hub-weu`; `rg-management-weu`, `law-management-weu`,
  `uami-management-ama-weu`). The connectivity stack passes explicit names to the
  module so it skips its default `<type>-hub-<location>-001` pattern;
  `customer_name` is now used only in tags.
- The consumer stacks pin the catalog at `v0.3.2`, up from foundation `v0.1.0`
  and connectivity `v0.2.0`. `v0.3.2` sets `resource_provider_registrations =
  none` in the catalog units, so the least-privilege Reader plan identity no
  longer fails `terraform init` by trying to register resource providers on a
  fresh deploy subscription. ONBOARDING step 5 registers the required providers
  out of band.
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
