# live

The deployed infrastructure for this customer, following the Gruntwork
infrastructure-live convention. Everything Terragrunt acts on lives here.

`root.hcl` (at the root of this folder) sets the remote state backend and exposes
the shared locals; each unit includes it and generates its own `backend.tf` and
providers. `tenant.hcl` sits alongside `root.hcl` so
`find_in_parent_folders("tenant.hcl")` resolves from every scope below it. The
folder tree mirrors the CAF management group hierarchy, using management group IDs
as folder names:

- `_foundation/` holds tenant-wide governance, deployed first, in dependency order: the
  management resources (`management-resources`), the MG hierarchy and base policy
  (`landing-zones`), and the Azure Monitor Baseline Alerts (`amba`). The `_` prefix
  sorts it first; see `docs/foundation-structure.md`.
- `platform/` is the Platform MG: connectivity, identity, management, security.
- `landingzones/` is the Landing Zones MG: corp, online, local.
- `decommissioned/` is the Decommissioned MG.
- `sandbox/` is the Sandbox MG.

The `_foundation/` units ship wired. Everything under `platform/` and
`landingzones/` is a README-only placeholder: the connectivity hub and the landing
zones are onboarded per customer, as new units on public Azure Verified Modules,
after the foundation is in place.
