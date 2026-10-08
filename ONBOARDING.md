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
- The operator's bootstrap GitHub App, installed on the organization that
  receives the repository, and its private key. The bootstrap authenticates as
  it to create the repository, the approver team, and the ruleset there. One
  App serves every customer of the operator; the bootstrap's
  `scripts/create-github-app.sh -p bootstrap` creates it in one click
- An MSP license and an entitlement for the customer's tenant and GitHub
  organization, for `/apply` (see Step 4)
- A point of contact at the customer for identity and networking decisions

## Step 1: Run the bootstrap

The repository, state backend, OIDC identities, environments, the approved-PR
ruleset, and the self-hosted runner are created by the Terraform bootstrap in
`nrit-solutions/nrit-alz-bootstrap`. Fill in a customer tfvars file and apply it.

The bootstrap generates the customer repository *from this template* (its
`github.tf` sets `template { owner, repository }` pointing at
`nrit-solutions/nrit-alz-customer-template`), so the new repository starts with
this whole tree, including the four caller workflows. The apply also creates:

- the state storage account and container (Entra ID auth only, firewalled),
- the plan and apply identities with federated credentials,
- the gated `plan` and `apply` GitHub environments,
- the `AZURE_*` and `BACKEND_*` repository variables, `RUNNER_LABEL`, and (when
  the client id is supplied) the `TFPR_CHECKS_APP_*` variable and secret pair,
- the `TFPR_LICENSE` and `TFPR_ENTITLEMENT` repository variables (set by the
  bootstrap onboarding script),
- `live/customer.hcl` and `.github/CODEOWNERS`, each written once into the new
  repository (see Steps 2 and 5),
- the `require-approved-pr-to-main` ruleset (the apply gate), with code owner
  review required by default,
- the self-hosted runner (when `network_posture = self_hosted_private`).

## Step 2: Set the customer-specific values

The tenant and subscription ids for CI come from the `AZURE_*` variables the
bootstrap set, so the pipeline needs no edits for them. The placeholders in
`live/tenant.hcl` and `live/_foundation/subscription.hcl` are only used for local
runs.

The bootstrap writes `live/customer.hcl` once, from the customer's tfvars, and
the repository owns it from then on: edit it here, and a bootstrap re-run never
overwrites it. Check its values before the first plan:

- `tenant_root_id`: the management group the ALZ hierarchy is created under, as
  the plain name. The tenant root group's name is the tenant id, which is what
  most customers want. For an existing intermediate management group, use its
  name; the group must already exist. Get it right before the first apply:
  changing it later moves the whole hierarchy and is destructive.
- `location` and `location_short`: the foundation's primary region.
  `live/_foundation/region.hcl` reads them, `root.hcl` generates a `context.tf`
  into each unit from that, and the units read `local.context`, so this is the
  only place the foundation region lives.
- `business_unit`: the `businessunit` tag on the platform resources.
- `amba_action_group_email`: a real monitored inbox. Azure Monitor Baseline
  Alerts is mandatory in this baseline and every AMBA alert routes to this
  address.

The other values to set for a new customer:

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
- `live/_foundation/region.hcl`: sets `environment`, which defaults to `prod`
  and becomes the `env` tag through
  `live/_foundation/management-resources/main.tf`. The tag policy allows `prod`,
  `staging`, and `dev` only, so a foundation that is not the customer's
  production estate must change it to one of those.

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
  pinned at an exact version. There is no separate pipeline version, and there
  is no moving tag: an upgrade is always a commit. To move to a new engine
  release, bump the `uses:` ref in every caller file. Install the Renovate
  GitHub App on the repository and `.github/renovate.json` opens that pull
  request for each engine release, all four callers in one. The invariants
  check fails a commit whose callers name different releases.
- **Providers.** Generate a `.terraform.lock.hcl` for every unit and commit them:

  ```sh
  for u in live/_foundation/*/; do
    terragrunt --working-dir "$u" init -backend=false
    TG_NO_AUTO_INIT=true terragrunt --working-dir "$u" run -- providers lock -platform=darwin_arm64 -platform=linux_amd64
  done
  ```

  The second command adds the `linux_amd64` hashes: the engine's provider
  cache verifies every cached package against the lock file on the runner,
  so a lock file written on a Mac alone misses the cache on every job. Put
  your own platform in place of `darwin_arm64` if it differs.

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

## Step 4: Check the license, set the cost gate, and require the merge gate

The caller workflows use the reusable workflows in the public
`nrit-solutions/tf-pr-ops` repository, and each job installs the engine runtime
of the pinned release from there. No engine credential is needed.

`/apply` needs a license. The bootstrap onboarding script sets the repository
variables `TFPR_LICENSE` and `TFPR_ENTITLEMENT`. Confirm both are set and that
`AZURE_TENANT_ID` holds the tenant the entitlement is bound to. Without them
plan, drift, and `/unlock` still work and `/apply` is refused. See
[License](https://docs.nrit.cloud/operations/license/) for what each message
means and how to fix it.

Set the cost gate. The bootstrap writes the `INFRACOST_API_KEY` secret and adds
`infracost` to `TFPR_EXTRA_TOOLS` when its `infracost_api_key` input is set.
Without a key, infracost is not installed and the cost section of the plan
comment is skipped. Check the variable rather than editing it blindly.

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
deliberately. The engine then applies only when the repository variable
`TFPR_ALLOW_UNREVIEWED_APPLY` is `true`. The bootstrap sets it when the count is
0 or the ruleset is turned off, and removes it otherwise, so do not set it by
hand. If `/apply` is refused with a message about the repository requiring no
reviews, this is the setting it means.

## Step 5: Set the code owners

The bootstrap writes `.github/CODEOWNERS` once, when it creates the repository.
It gives `.github/` and `projects.yml` to the apply approvers team the
bootstrap creates (`<customer_name>-alz-apply-approvers`): the engine callers,
the gate hooks, and the invariants script that guards them. The
repository owns the file from then on, and a bootstrap re-run never overwrites
it. The bootstrap's ruleset requires code owner review by default
(`require_code_owner_review`). Check the file on the repository's code page:
GitHub flags an owner it cannot resolve there, and skips that line, so the path
would need no owner review. A single-writer organization sets
`require_code_owner_review = false` in its tfvars, because nobody can approve
their own pull request.

`LICENSE` is Apache-2.0, the license the template is published under. It covers
this repository's files only; the engine core and the service around it are
governed by the agreement with NRIT, not by this file.

## Step 6: First plan

Open a pull request with a trivial change (for example a comment in
`live/customer.hcl`) to trigger the plan. Review the output posted on the PR. To plan
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
