# Examples

Copyable `live/` subtrees, one per scenario on the docs site. Each folder holds
exactly the files you add to your repository for that scenario, at the paths
they go to, with every tenant-specific value set to a placeholder you replace.

| Folder | Scenario page |
| --- | --- |
| `connectivity/hub-spoke-minimal/` | [Minimal hub and spoke](https://docs.nrit.cloud/scenarios/connectivity/hub-spoke-minimal/) |
| `connectivity/hub-spoke-firewall/` | [Hub and spoke with Azure Firewall](https://docs.nrit.cloud/scenarios/connectivity/hub-spoke-firewall/) |
| `connectivity/vwan-firewall/` | [Virtual WAN with Azure Firewall](https://docs.nrit.cloud/scenarios/connectivity/vwan-firewall/) |
| `landing-zones/adopt-subscription/` | [Landing zone on an existing subscription](https://docs.nrit.cloud/scenarios/landing-zones/adopt-subscription/) |
| `landing-zones/vend-subscription/` | [Landing zone with a new subscription](https://docs.nrit.cloud/scenarios/landing-zones/vend-subscription/) |
| `options/multiple-environments/` | [Several environments in one subscription](https://docs.nrit.cloud/scenarios/options/multiple-environments/) |
| `options/workload-unit/` | [Add a workload unit](https://docs.nrit.cloud/scenarios/options/add-a-workload-unit/) |

## How to use one

1. Copy the example's `live/` subtree over your repository's `live/`. Folder
   names are management group ids, then the subscription folder, then the
   region, then the unit, so the files land where discovery expects them.
2. Replace every `00000000-0000-0000-0000-000000000000` with the real id the
   comment above it names, and rename the subscription folder and the
   `purpose` local to the customer's values.
3. Read every `main.tf` comment that says "replace", "change both together" or
   "literal". Those are the cross-unit couplings by convention.
4. Open a pull request. Discovery picks up the new units, plans them, and
   posts the result. Apply in the order the scenario page gives.

Nothing under `examples/` is a unit: discovery is scoped to `live/`, and the
merge gate ignores this folder (`gate_ignore` in `projects.yml`). Keep it in
your repository or delete it; neither affects a plan.

## Keeping them honest

Module versions in the examples are pinned exactly, like every unit. When a
pin moves in the examples, the scenario page says so. The examples are
validated by `terraform validate` against the module schemas and by a plan on
NRIT's sandbox tenant before they are published; they are not applied there.
