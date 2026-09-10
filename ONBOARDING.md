# Onboarding checklist

This document walks through standing up a new customer landing zone from this
template. Steps 1 to 5 are run once by the operator (NRIT, or the MSP running
the platform in its own GitHub organization); the rest are the normal pull
request flow.

## Prerequisites

- Azure tenant (existing or newly created) for the customer
- Owner at the scope the deploy identities operate at (the tenant root group, or
  the customer's ALZ parent management group), granted to the operator running the
  bootstrap
- A management subscription (it holds the shared state backend and the runner).
  A connectivity subscription too if the customer runs a hub; it is optional and
  can be added later
- GitHub organization for the customer repository
- A GitHub token with `repo` and `admin:org` scope in the organization that
  receives the repository, for the operator only. The bootstrap creates the
  approver team and the ruleset there; nothing is needed on the NRIT organization
- The engine App credentials for your organization (client id and private key).
  Inside nrit-solutions this is the `nrit-engine-reader` App; any other
  organization gets its own App from NRIT
- A point of contact at the customer for identity and networking decisions

## Step 1: Run the bootstrap

The repository, state backend, OIDC identities, environments, the approved-PR
ruleset, and the self-hosted runner are created by the Terraform bootstrap in
`nrit-solutions/nrit-alz-bootstrap`. Fill in a customer tfvars file and apply it.

The bootstrap generates the customer repository *from this template* (its
`github.tf` sets `template { owner, repository }` pointing at
`nrit-solutions/nrit-alz-customer-template`), so the new repository starts with
this whole tree, including the two caller workflows. The apply also creates:

- the state storage account and container (Entra ID auth only, firewalled),
- the plan and apply identities with federated credentials,
- the gated `plan` and `apply` GitHub environments,
- the `AZURE_*` and `BACKEND_*` repository variables, `RUNNER_LABEL`, and (when
  the client ids are supplied) the `ENGINE_APP_*` and `TFPR_CHECKS_APP_*`
  variable and secret pairs,
- the `require-approved-pr-to-main` ruleset (the apply gate),
- the self-hosted runner (when `network_posture = self_hosted_private`).

## Step 2: Set the customer-specific values

The tenant and subscription ids for CI come from the `AZURE_*` variables the
bootstrap set, so the pipeline needs no edits for them. The placeholders in
`live/tenant.hcl` and `live/_foundation/subscription.hcl` are only used for local
runs.

The values to set for a new customer:

- `live/_foundation/landing-zones/main.tf`: `architecture_name` defaults to `nrit`,
  the only architecture the vendored library defines
  (`live/_foundation/landing-zones/lib/architecture_definitions/`). Leave it alone
  unless you add a second architecture definition to that library, or point the
  unit at a different library that names its architecture something else.
  `connectivity_subscription_id` defaults to an empty string, which omits the
  connectivity entry from `subscription_placement`. Set it to the connectivity
  subscription id when the customer has one; leave it empty when they do not and
  the foundation plans and applies without it. Placement is not permanent: set the
  id later and re-apply to move the subscription under the Connectivity MG.
- `live/_foundation/management-resources/main.tf`: set the `businessunit` tag
  (currently `changeme`) to the customer's short name.
- `live/_foundation/amba/main.tf`: replace the `amba_action_group_email`
  placeholder (`alerts@example.com`) with a real monitored inbox. Azure Monitor
  Baseline Alerts is mandatory in the NRIT baseline and every AMBA alert routes to
  this address.
- `live/_foundation/region.hcl`: region defaults to `westeurope`; change only if
  the customer specifies otherwise. Set `location` and `location_short` here and
  nowhere else. `root.hcl` generates a `context.tf` into each unit from this file,
  and the units read `local.context`, so this is the only place the region lives.
  The same file sets `environment`, which defaults to `prod` and becomes the `env`
  tag through `live/_foundation/management-resources/main.tf`. The tag policy
  allows `prod`, `staging`, and `dev` only, so a foundation that is not the
  customer's production estate must change it to one of those.
- `live/tenant.hcl`: `tenant_root_id` is the management group the ALZ hierarchy is
  created under. It defaults to the tenant root group, which is what most
  customers want. Set it to an existing intermediate management group id when the
  customer already has one, and do it before the first apply: changing it later
  moves the whole hierarchy and is destructive.

The backend names are never edited here. They come from the `BACKEND_*` variables
the bootstrap set. All subscriptions share that one state account (in the
management subscription), accessed by Entra ID; each folder's `subscription.hcl` is
only the deploy target, not the state location.

## Step 3: Pin versions

Three kinds of version are pinned in this repository:

- **Library and AVM versions.** The `landing-zones` unit reads the upstream ALZ
  library at a pinned `ref` plus the NRIT library vendored under
  `live/_foundation/landing-zones/lib/` (a local path, so it carries no `ref`).
  The `amba` unit reads the upstream ALZ and AMBA libraries, both at pinned refs.
  Keep the `platform/alz` ref the same in both units. Pin AVM module versions with
  the `version` argument in each unit's `main.tf`. See
  [Versions and upgrades](https://docs.nrit.cloud/reference/versions/).
- **The engine.** The four workflows in `.github/workflows/` call the reusable
  workflows and the dispatch action published in `nrit-solutions/tf-pr-ops`,
  pinned at an exact version with a matching `engine_ref`. There is no separate pipeline version, and there is no moving tag:
  an upgrade is always a commit. To move to a new engine release, bump both pins
  together (the `uses:` ref and `engine_ref`) in each caller file.
- **Providers.** Generate a `.terraform.lock.hcl` for every unit and commit them:

  ```sh
  for u in live/_foundation/*/; do
    terragrunt --working-dir "$u" init -backend=false
  done
  ```

  The template deliberately ships none. A lock file records the exact provider
  versions resolved at the moment it is written, so a pre-generated one would
  start every customer on whatever happened to resolve the day the template was
  last touched, quietly further behind with each month that passes. Generating
  them here pins this customer to current providers, on purpose, with the versions
  visible in the first pull request.

  Until this is done, provider versions re-resolve on every run, so an `/apply`
  can use a different version than the plan that was reviewed. The pre-commit
  invariants check warns about it, without blocking, until the files exist. See
  `AGENTS.md` for how to move a provider version afterwards.

## Step 4: Grant access, set the cost gate, and require the merge gate

The caller workflows reference the public entrypoint repository
`nrit-solutions/tf-pr-ops`, which any organization can call. The engine core
they run is private: every job checks it out at the pinned version with a
GitHub App token minted from `ENGINE_APP_CLIENT_ID` (variable) and
`ENGINE_APP_PRIVATE_KEY` (secret). The App is issued by NRIT per organization
and installed on the NRIT organization, so nothing is installed on yours.
Confirm both values are set (the bootstrap sets them when a client id is
supplied); without them the first pull request fails at the dispatch step with a
message naming the missing variable.

Set the cost gate: add the `INFRACOST_API_KEY` secret. It is the only part the
bootstrap does not set. The bootstrap already sets the `TFPR_EXTRA_TOOLS`
variable and its value includes `infracost` (`infracost` on a self-hosted runner,
whose image already carries conftest and checkov; `conftest checkov infracost` on
GitHub-hosted). Check the variable rather than editing it blindly.

Make `tf-pr-ops / merge-gate` a required status check on the main branch.
The bootstrap's `require-approved-pr-to-main` ruleset takes the check context from
its `required_status_checks` variable; set it there, or add the check by hand.

Decide how `/apply` is approved. The engine reads GitHub's review decision, so
the number of approvals is whatever the ruleset requires. The bootstrap defaults
`required_approving_review_count` to 1, which is what most customers want and
needs nothing further here.

A repository that requires no approving reviews is a special case. GitHub reports
no review decision at all, which the engine refuses rather than treats as consent:
an empty decision is indistinguishable from a ruleset that was removed, so
allowing it would let the apply gate disappear with no signal. A single-writer
organization cannot self-approve on GitHub and so sets the count to 0
deliberately; it must then set the repository variable
`TF_PR_OPS_ALLOW_UNREVIEWED_APPLY` to `true` to allow `/apply`. Leave that
variable unset everywhere else. If `/apply` is refused with a message about the
repository requiring no reviews, this is the setting it means.

## Step 5: Set the code owners

`.github/CODEOWNERS` ships as a commented example. Point it at a team that
exists in the customer's organization, or delete the file if the customer wants
no code owners. Code owners are not enforced today: the bootstrap sets
`require_code_owner_review = false` in its `github.tf`. Turn that on in the
customer's tfvars if the customer wants owner review required before merge.

`LICENSE` is Apache-2.0, the license the template is published under. It covers
this repository's files only; the engine core and the service around it are
governed by the agreement with NRIT, not by this file.

## Step 6: First plan

Open a pull request with a trivial change (for example a comment in
`live/tenant.hcl`) to trigger the plan. Review the output posted on the PR. To plan
the foundation, open a PR touching the `_foundation/` units.

## Step 7: First apply

After review and approval, comment `/apply` on the PR. The foundation applies in
dependency order automatically: `management-resources`, then `landing-zones`, then
`amba`. Every unit, foundation included, applies through the same comment-ops flow.
Once applied, the merge gate turns green and the PR merges.

Expect the first foundation apply to take sixty to ninety minutes due to policy
propagation.

## Escape hatch: vendoring the engine

The callers consume the engine as a reusable workflow, so it is not stored in
this repository. If a customer needs a fully self-contained repository (no
external workflow reference), vendor the engine instead: copy the private core's
`.github/workflows/`, `.github/actions/`, `scripts/`, and Go sources in at a tag,
and the `post_plan` hooks keep working because `$TFPR_ENGINE_DIR` defaults to the
workspace in vendored mode. This needs read access to the core, which NRIT grants
per agreement; the core README carries the vendored-mode contract.
