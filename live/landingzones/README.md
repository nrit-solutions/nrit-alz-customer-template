# landingzones

Management group: **Landing Zones** (id `landingzones`), child of `alz`.

Holds the workload landing zones, grouped by archetype. Child management
groups:

- `corp` — corp-connected workloads (no public ingress by default)
- `online` — internet-facing workloads

Both are placeholders until a customer's first landing zone is onboarded; see
`corp/README.md` and `online/README.md`.
