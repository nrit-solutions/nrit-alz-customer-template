# live

The deployed infrastructure state for this client, following the Gruntwork
infrastructure-live convention. Everything Terragrunt acts on lives here.

`root.hcl` (at the root of this folder) generates `provider.tf` and
`backend.tf` for every unit. The folder tree below it mirrors the CAF
management group hierarchy, using management group IDs as folder names:

- `tenant/` — tenant root config and the foundation stack that builds the MG
  hierarchy and root policies
- `platform/` — Platform MG: connectivity, identity, management, security
- `landingzones/` — Landing Zones MG: corp, online
- `decommissioned/` — Decommissioned MG
- `sandbox/` — Sandbox MG

Scaffold only. `root.hcl` and the `*.hcl` configuration are not written yet.
