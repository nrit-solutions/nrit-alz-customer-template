# Policy and security gates

Every plan (and the daily drift sweep) runs three checks against the Terraform
plan, via `post_plan` hooks in `projects.yml`. Findings appear in the PR run
comment and in drift issues, under an "Additional output" panel that stays
collapsed when clean and expands automatically when a gate reports a finding.

## What runs

| Gate | Tool | Checks | Config |
|---|---|---|---|
| Policy | conftest | `policy/*.rego` against the plan JSON | `policy/governance.rego` |
| Security | checkov | built-in checks against the plan JSON | engine `checkov-gate.sh` |
| Cost | infracost | monthly cost of the plan JSON | engine `infracost-gate.sh` |

The gate scripts live in the `nrit-tf-pr-ops` engine, not in this repository. The
`post_plan` hooks in `projects.yml` run them from `$TFPR_ENGINE_DIR`, the engine
checkout the reusable workflow provides.

conftest and checkov are baked into the self-hosted runner image (see the
nrit-alz-bootstrap `runner-image`). infracost is a static binary
installed per run, so it is not in the image: set the `TFPR_EXTRA_TOOLS` repository
variable to include `infracost`.

## Cost gate setup

infracost needs an API key for its hosted Cloud Pricing API:

1. Create a free key: `infracost auth login` (or register at dashboard.infracost.io
   and copy the key from Org Settings).
2. Add it as the `INFRACOST_API_KEY` repository secret (never in tfvars). The plan
   and drift workflows pass it through to the hook.
3. Add `infracost` to the `TFPR_EXTRA_TOOLS` repository variable so the runner
   installs the binary.

Until the key and variable are set, the hook notes it and skips.

Data residency: infracost sends per-resource region and SKU to its hosted pricing
API to look up prices. The Terraform code itself does not leave. This is an
accepted trade-off; the self-hosted pricing API that would avoid the lookup egress
is behind a paid Infracost plan.

## Report-only today

All three gates start advisory, so they surface findings without blocking a merge:

- conftest runs `warn` rules only (`policy/governance.rego`). Warnings do not gate.
- checkov runs with `CHECKOV_SOFT_FAIL`, so it reports but never fails the build.
- infracost is informational: the hook always exits 0 and never gates.

## Enforcing a gate

- **conftest:** add a `deny` rule to `policy/` (see `examples/policy/tags.rego` for
  the plan-JSON patterns). A deny fails the gate and blocks the PR.
- **checkov:** drop `CHECKOV_SOFT_FAIL` from the checkov hook in `projects.yml`, or
  scope it with `CHECKOV_HARD_FAIL_ON` (check IDs) once findings are triaged.

Enforce deliberately, after reviewing the report-only findings, so a wall of
existing findings does not block every PR on day one.
