# Operations runbook

Common operational procedures.

## Teardown ordering

When tearing a tenant down, delete policy assignments and any custom
set-definitions or definitions before deleting management groups. Order:
assignments, then set-definitions, then definitions, then management groups,
bottom-up.

Deleting a management group while it still has a policy assignment orphans
that assignment into an un-deletable ghost. If the management group is later
recreated, the foundation apply hangs indefinitely trying to (re)create that
assignment on the inconsistent scope.

## AMBA remediation

Applying the foundation assigns the AMBA `DeployIfNotExists` policies but does
not deploy the action group or alerts. Trigger it: `az policy state
trigger-scan` per subscription, then `az policy remediation create` for the
`Deploy-AMBA-*` assignments.

`--resource-discovery-mode ReEvaluateCompliance` is only supported at
subscription scope and below, not at management-group scope, so scan the
subscriptions first, then remediate.

## The change process

Every change is a pull request. There is no manual dispatch and no local apply.

1. Branch, edit the unit, open a PR. The engine plans every impacted unit and
   posts the plan as a comment, with the policy, security, and cost gate output.
2. Read the plan. The gate panel expands on its own when a gate has a finding.
3. Get the required approval, then comment `/apply`. The engine applies the
   changed units in dependency order and reacts to your comment as it goes.
4. `tf-pr-ops / merge-gate` goes green once the applied set matches what
   the PR changed. Merge.

The gate stays red if the PR touched Terraform but no unit was selected, so a new
or removed unit cannot merge without being applied. If that happens, the unit path
is wrong or missing from `projects.yml`.

## Adding a workload to a landing zone

Work down the tree, one PR per step so each plan stays readable.

1. Create the subscription folder under the target management group, for example
   `live/landingzones/corp/<workload>/`, holding `subscription.hcl` with the
   subscription id.
2. Add the `lz-vending` unit under `<workload>/_global/`, with its own co-located
   `region.hcl` (root.hcl reads a region unconditionally, so the file must exist
   even though the unit is region-agnostic). It places the subscription under the
   management group and creates nothing else.
3. Add the network unit under `<workload>/<region>/network/`. It creates the spoke
   virtual network and peers it to the hub. The connectivity hub and step 2 must
   be applied first.
4. Add the workload units beside it, each on the matching `Azure/avm-res-*`
   module at a pinned `version`.

See `live/landingzones/corp/README.md` for the module names and the two settings
the ALZ policies force (an NSG on every subnet, and no remote gateways when the
hub has none).

## Drift

The `drift` workflow runs daily at 06:17 UTC and can be dispatched by hand. It
plans every unit and opens or updates a GitHub issue per unit that has drifted,
with the same gate output a PR plan gets.

Triage a drift issue by cause, not by re-applying blindly:

- **A policy `deployIfNotExists` remediation changed the resource.** Common for
  AMBA and for inherited tags. Match the code to what the policy deploys, or stop
  managing the attribute here. The AMBA resource group is the standing example:
  it is left AMBA-owned for exactly this reason.
- **Someone changed it in the portal.** Re-apply through a PR to put it back, and
  raise the access that allowed it.
- **A provider or module upgrade changed the plan.** Pin work belongs in its own
  PR. See `upgrade-guide.md`.

A drift issue is never closed by applying outside the PR flow. Open a PR, let the
plan confirm the fix, and `/apply` it.

## Rotating credentials

The deploy identities are OIDC federated credentials with no secret to rotate;
they are created and changed by the bootstrap in `nrit-alz-bootstrap`, not here.
Two repository items are real secrets and do rotate:

- `CATALOG_APP_PRIVATE_KEY`: the GitHub App private key used to check the engine
  repository out. Generate a new key on the App, update the secret, then delete
  the old key. The name is historical; see `ONBOARDING.md` step 4.
- `INFRACOST_API_KEY`: replace the secret with a new key. The cost gate notes it
  and skips if the key is missing, so a bad rotation degrades to no cost output
  rather than a failed plan.

After either rotation, dispatch the `drift` workflow to confirm the engine still
authenticates before the next PR needs it.
