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

Placeholder. Still to be written: adding a workload to a landing zone,
rotating credentials, handling drift, and the plan-and-apply change process.
