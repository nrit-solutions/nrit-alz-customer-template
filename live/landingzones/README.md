# landingzones

Management group: **Landing Zones** (id `landingzones`), child of `alz`.

Holds the workload landing zones, grouped by archetype. Child management
groups:

- `corp` holds corp-connected workloads (no public ingress by default)
- `online` holds internet-facing workloads
- `local` holds Azure Local landing zones. Stock ALZ, rarely used.

All three are placeholders until a customer's first landing zone is onboarded;
see `corp/README.md`, `online/README.md`, and `local/README.md`.
