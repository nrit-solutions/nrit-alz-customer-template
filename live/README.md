# live

The deployed infrastructure state for this client, following the Gruntwork
infrastructure-live convention. Everything Terragrunt acts on lives here.

`root.hcl` (at the root of this folder) sets the remote state backend and
exposes the shared locals; each unit includes it and generates its own
`backend.tf` and `provider.tf`. `tenant.hcl` sits alongside `root.hcl` so
`find_in_parent_folders("tenant.hcl")` resolves from every scope below it. The
folder tree below mirrors the CAF management group hierarchy, using management
group IDs as folder names:

- `tenant/` — tenant-scope deployments: the foundation stack under `_global/`
  that builds the MG hierarchy, policy, and the management resources
- `platform/` — Platform MG: connectivity, identity, management, security
- `landingzones/` — Landing Zones MG: corp, online
- `decommissioned/` — Decommissioned MG
- `sandbox/` — Sandbox MG

The foundation under `tenant/_global/caf-platform-foundation/` is wired. The
connectivity and landing-zone folders are still scaffold (later phases).
