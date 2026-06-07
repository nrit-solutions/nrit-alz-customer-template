# corp

Management group: **Corp** (id `corp`), child of `landingzones`.

Corp-connected landing zones. One named subscription folder per environment:

- `corp-prd/` — production (holds the `webapp-sql-baseline` workload in v1)
- `corp-tst/` — test (no workload yet, scaffolded to show where one goes)

Scaffold only. The `subscription.hcl`, `region.hcl`, and workload stack
configs are not written yet.
