# Onboarding checklist

This document walks through standing up a new customer landing zone from this
template. Steps 1 to 4 are run once by NRIT; the rest are the normal pull
request flow.

## Prerequisites

- Azure tenant (existing or newly created) for the customer
- Owner at the scope the deploy identities operate at (the tenant root group, or
  the customer's ALZ parent management group), granted to the operator running the
  bootstrap
- A connectivity subscription and a management subscription (the management
  subscription holds the shared state backend and runner)
- GitHub organisation for the customer repository
- A GitHub token with `repo` and `admin:org` scope, for the operator only
- A point of contact at the customer for identity and networking decisions

## Step 1: Run the bootstrap (NRIT)

The repository, state backend, OIDC identities, environments, the approved-PR
ruleset, and the self-hosted runner are created by the Terraform bootstrap in
`nrit-solutions/nrit-alz-bootstrap`. Fill in a customer tfvars file and apply it.

The bootstrap generates the customer repository *from this template* (its
`github.tf` sets `template { owner, repository }` pointing at
`nrit-solutions/nrit-azure-customer-template`), so the new repository starts with
this whole tree, including the two caller workflows. The apply also creates:

- the state storage account and container (Entra ID auth only, firewalled),
- the plan and apply identities with federated credentials,
- the gated `plan` and `apply` GitHub environments,
- the `AZURE_*` and `BACKEND_*` repository variables, `RUNNER_LABEL`, and (when a
  client id is supplied) `CATALOG_APP_CLIENT_ID` plus the `CATALOG_APP_PRIVATE_KEY`
  secret,
- the `require-approved-pr-to-main` ruleset (the apply gate),
- the self-hosted runner (when `network_posture = self_hosted_private`).

## Step 2: Set the customer-specific values

The tenant and subscription ids for CI come from the `AZURE_*` variables the
bootstrap set, so the pipeline needs no edits for them. The placeholders in
`live/tenant.hcl` and `live/_foundation/subscription.hcl` are only used for local
runs.

The values to set for a new customer:

- `live/_foundation/landing-zones/main.tf`: set `architecture_name` (currently the
  placeholder `changeme`). It must match an architecture defined in the alz library
  referenced from `live/_foundation/landing-zones/terragrunt.hcl`. Set
  `connectivity_subscription_id` (currently zeros) if you place a connectivity
  subscription.
- `live/_foundation/management-resources/main.tf`: set the `customer` tag
  (currently `changeme`) to the customer's short name.
- `live/_foundation/amba/main.tf`: replace the `amba_action_group_email`
  placeholder (`alerts@example.com`) with a real monitored inbox. Azure Monitor
  Baseline Alerts is mandatory in the NRIT baseline and every AMBA alert routes to
  this address.
- `live/_foundation/region.hcl`: region defaults to `westeurope`; change only if
  the customer specifies otherwise.

The backend names are never edited here. They come from the `BACKEND_*` variables
the bootstrap set. All subscriptions share that one state account (in the
management subscription), accessed by Entra ID; each folder's `subscription.hcl` is
only the deploy target, not the state location.

## Step 3: Pin versions

Two kinds of version are pinned in this repository:

- **Catalog and AVM versions.** The `landing-zones` unit references the private
  catalog policy library in `live/_foundation/landing-zones/terragrunt.hcl`. Pin
  the `ref` on each `library_references` entry. Pin AVM module versions with the
  `version` argument in each unit's `main.tf`.
- **The engine.** The two workflows in `.github/workflows/` call the
  `nrit-tf-pr-ops` reusable workflows, pinned `@v1` with a matching `engine_ref: v1`.
  There is no separate pipeline version. To move to a new engine release, bump both
  pins together (the `uses:` ref and `engine_ref`) in each caller file.

## Step 4: Grant access, set the cost gate, and require the merge gate

The `landing-zones` unit fetches the policy library from the private
`nrit-terragrunt-catalog` repository, so the org must allow this repository to
reach it:

```sh
gh api -X PUT repos/nrit-solutions/nrit-terragrunt-catalog/actions/permissions/access -f access_level=organization
```

Terragrunt shells out to `git`, which needs a credential for
`github.com/nrit-solutions`. The workflow mints a GitHub App token for this from
`CATALOG_APP_CLIENT_ID` (variable) and `CATALOG_APP_PRIVATE_KEY` (secret) and
rewrites the git URL. The same App token checks out the private engine repository,
so confirm both are set (the bootstrap sets them when a client id is supplied).

Set the cost gate: `INFRACOST_API_KEY` (secret) and add `infracost` to the
`TFPR_EXTRA_TOOLS` variable. Neither is set by the bootstrap.

Make `terraform-pr-ops / merge-gate` a required status check on the main branch.
The bootstrap's `require-approved-pr-to-main` ruleset takes the check context from
its `required_status_checks` variable; set it there, or add the check by hand.

## Step 5: First plan

Open a pull request with a trivial change (for example a comment in
`live/tenant.hcl`) to trigger the plan. Review the output posted on the PR. To plan
the foundation, open a PR touching the `_foundation/` units.

## Step 6: First apply

After review and approval, comment `/apply` on the PR. The foundation applies in
dependency order automatically: `management-resources`, then `landing-zones`, then
`amba`. Every unit, foundation included, applies through the same comment-ops flow.
Once applied, the merge gate turns green and the PR merges.

Expect the first foundation apply to take sixty to ninety minutes due to policy
propagation.

## Escape hatch: vendoring the engine

The callers consume `nrit-tf-pr-ops` as a reusable workflow, so the engine is not
stored in this repository. If a customer needs a fully self-contained repository
(no external workflow reference), vendor the engine instead: copy the
`nrit-tf-pr-ops` `.github/workflows/`, `.github/actions/setup-tools/`, and
`scripts/` in at a tag, and the `post_plan` hooks keep working because
`$TFPR_ENGINE_DIR` defaults to the workspace in vendored mode. See the
`nrit-tf-pr-ops` README for the vendored-mode contract.
