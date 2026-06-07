# landingzones

Management group: **Landing Zones** (id `landingzones`), child of `alz`.

Holds the workload landing zones, grouped by archetype. Child management
groups:

- `corp` — corp-connected workloads (no public ingress by default)
- `online` — internet-facing workloads

Each archetype MG holds one named subscription folder per environment, for
example `corp/corp-prd/` and `corp/corp-tst/`.
