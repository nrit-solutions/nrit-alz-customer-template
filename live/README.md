# live

The deployed infrastructure state for this client, following the Gruntwork
infrastructure-live convention. Everything Terragrunt acts on lives here.

`root.hcl` (at the root of this folder) sets the remote state backend and
exposes the shared locals; each unit includes it and generates its own
`backend.tf` and `provider.tf`. `tenant.hcl` sits alongside `root.hcl` so
`find_in_parent_folders("tenant.hcl")` resolves from every scope below it. The
folder tree below mirrors the CAF management group hierarchy, using management
group IDs as folder names:

- `platform/` — Platform MG: connectivity, identity, management, security. The
  platform foundation (the MG hierarchy, policy, and the management
  resources) lives under
  `platform/management/westeurope/caf-platform-foundation/`
- `landingzones/` — Landing Zones MG: corp, online (placeholders; onboarded
  per customer)
- `decommissioned/` — Decommissioned MG
- `sandbox/` — Sandbox MG

The platform foundation and the connectivity hub are wired. `identity`,
`security`, and the landing zones are placeholders until a customer's
subscriptions are onboarded.
