## What and why

<!-- What does this change deploy or modify, and why? -->

## Scope

<!-- A unit is a folder with a terragrunt.hcl. List every unit this PR touches. -->

- Units impacted:
- Subscription / landing zone:
- Version pins moved (AVM `version` in `main.tf`, policy library `ref`, engine pins):
  <!-- Write "none" if no pin moved. Engine pins are the uses: ref and engine_ref
       in both terraform-pr-ops.yml and drift.yml. They must match. -->

## Checklist

- [ ] Plan comment reviewed for every impacted unit, including deletes and replaces
- [ ] Policy, security, and cost gate output reviewed
- [ ] If an engine pin moved, the `uses:` ref and `engine_ref` match in both workflows
- [ ] Affected `subscription.hcl` / `region.hcl` values confirmed
- [ ] Reviewer from the required approver group requested
- [ ] `/apply` run after approval and the apply succeeded
- [ ] `terraform-pr-ops / merge-gate` is green
