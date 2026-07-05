# Onboarding checklist

This document walks through onboarding a new customer to NRIT's Azure platform
delivery. Steps 1 to 3 are run once by NRIT; the rest are the normal pull
request flow.

## Prerequisites

- Azure tenant (existing or newly created) for the customer
- Owner at the scope the deploy identities operate at (the tenant root group, or
  the customer's ALZ parent management group), granted to the operator running
  the bootstrap
- GitHub organisation for the customer repository
- A GitHub PAT with `repo` and `admin:org` scope, for the operator only,
  supplied via the `GITHUB_TOKEN` environment variable
- A point of contact at the customer for identity and networking decisions

## Step 1: Run the bootstrap (NRIT)

The repository, state backend, and OIDC identities are all created by the
Terraform bootstrap in the pipelines repository
(`nrit-azure-pipelines/bootstrap`, see ADR 11). There is no manual template
generation or state script.

1. Copy `bootstrap/customers/_example.tfvars` to `bootstrap/customers/<customer>.tfvars`
   and fill in the tenant, management subscription, repository name, approvers,
   and `network_posture` (`self_hosted_private` for production).
2. Authenticate to the customer tenant and export the PAT, then
   `terraform apply -var-file=customers/<customer>.tfvars`.

This generates the repository from this template, creates the state account and
container (Entra ID auth only), the plan and apply identities with federated
credentials, and sets the `AZURE_*` and `BACKEND_*` Action variables and the
gated `plan` and `apply` environments.

## Step 2: Replace placeholders

The tenant and subscription ids come from the `AZURE_TENANT_ID` and
`AZURE_SUBSCRIPTION_ID` Action variables the bootstrap set, which the pipeline
injects at run time, so CI needs no edits for them. The placeholders in
`live/tenant.hcl` and `live/**/subscription.hcl` are only used for local runs;
replace them, or export the variables, if you plan against the tenant locally.

The values you must set:

- `live/platform/management/westeurope/caf-platform-foundation/terragrunt.stack.hcl`:
  set `customer_name` (short, lowercase) in the `locals` block. Replace the
  `amba_action_group_email` placeholder (`alerts@example.com`) with a real
  monitored inbox: Azure Monitor Baseline Alerts is on by default and every AMBA
  alert routes to this address. Set `subscription_placement` if you are placing
  subscriptions into management groups in this first apply.
- `live/platform/connectivity/westeurope/caf-connectivity-hub/terragrunt.stack.hcl`:
  set `customer_name` to match.
- `live/platform/connectivity/subscription.hcl`: set
  the connectivity subscription id (the hub deploys there, a different
  subscription from the foundation's management subscription).

Region defaults to `westeurope`; change `live/**/region.hcl` only if the
customer specifies otherwise.

The foundation ships nrit tag governance (`Enforce-Tag-Gov`) in Audit. Every
resource group must carry `workload`, `owner`, `criticality`, and
`confidentiality`, each with an allowed value (criticality: `mission-critical`,
`high`, `medium`, `low`; confidentiality: `public`, `internal`, `confidential`,
`restricted`; environment: `prod`, `nonprod`, `dev`), or it is flagged now and
denied once the policy effects are set to Deny. Set the placeholder `owner`,
`criticality`, and `confidentiality` values in the foundation and hub `tags`
blocks per workload.

The backend names are never edited here. They come from the `BACKEND_*` Action
variables the bootstrap set. All subscriptions share that one state account
(in the management subscription, where the bootstrap puts the state, runners,
and identities), accessed by Entra ID; each folder's `subscription.hcl` is only
the deploy target, not the state location.

The connectivity hub ships as the minimal validated config (firewall on, DDoS
and private DNS off). To have the foundation policy assignments reference a live
DDoS plan and private DNS, turn those on in the connectivity stack and set
`connectivity_subscription_id` plus the DDoS/DNS names in the foundation stack.

DDoS: the ALZ `Enable-DDoS-VNET` modify policy ships on by default and injects
a DDoS plan reference into every VNet the moment it is created. Until that is
resolved, no VNet in this tenant can be created, including the connectivity
hub, so its first apply will fail. Resolve it one of two ways before that
apply: deploy a real DDoS protection plan and wire its id into the
foundation's policy default values, or open the foundation stack
(`caf-platform-foundation/terragrunt.stack.hcl`) and uncomment the
`policy_assignments_to_modify` carve-out that disables the modify policy for
`connectivity` and `landingzones` (fine for a minimal or dev tenant with no
DDoS plan; not recommended for production). The same blocker applies to any
landing-zone spoke network onboarded later.

## Step 3: Pin catalog and pipelines versions

Update `catalog_ref` in each `terragrunt.stack.hcl` and the `@v<version>` ref on
each reusable workflow in `.github/workflows/`. The workflow ref must match the
tag the bootstrap pinned the federated credential to (its `pipelines_ref`,
default `v0.4.2`), or OIDC login fails. `drift.yml` is the exception: it pins
`terragrunt-drift.yml` at the separate `drift_workflow_ref` (default `v0.4.2`),
because the drift credential was added after the plan and apply pin. Keep the two
in step.

## Step 4: Grant cross-repository Actions access

The customer repository calls reusable workflows in the private
`nrit-azure-pipelines` repository and fetches stacks from the private
`nrit-terragrunt-catalog` repository. Both are private, so the org must allow
the customer repository's workflows to reach them. On each of those two
repositories set Actions access to the organisation (Settings, Actions,
General, "Access", or once with the API):

```sh
gh api -X PUT repos/nrit-solutions/nrit-azure-pipelines/actions/permissions/access -f access_level=organization
gh api -X PUT repos/nrit-solutions/nrit-terragrunt-catalog/actions/permissions/access -f access_level=organization
```

Without the pipelines grant the workflow run fails immediately with no jobs
(the reusable workflow cannot be resolved). Without the catalog grant the run
starts but `terragrunt stack generate` cannot clone the catalog. The catalog
grant alone is not always enough: `terragrunt` shells out to `git`, which needs
a credential for `github.com/nrit-solutions`. If the fetch still fails, supply
the runner a token (a GitHub App installation token or a read-only PAT)
configured as a git credential.

## Step 5: Register resource providers

The deploy identities run least privilege: the plan identity is Reader and cannot
register Azure resource providers, so the catalog units set
`resource_provider_registrations = "none"`. Register the providers each deploy
subscription needs before the first run, using an account with rights on the
subscription. Every deploy subscription needs `Microsoft.PolicyInsights` for the
AMBA policy remediation (step 8); the connectivity subscription also needs at
least `Microsoft.Network`:

```sh
az provider register --namespace Microsoft.PolicyInsights --subscription <sub-id>
az provider register --namespace Microsoft.Network --subscription <connectivity-sub-id>
```

Register any further providers a workload uses (for example `Microsoft.Web` or
`Microsoft.Sql`) on its landing zone subscription the same way. Without the
provider the first plan fails at `terraform init` with an authorization error on
`Microsoft.X/register/action`; without `Microsoft.PolicyInsights` the AMBA
remediation fails with `SubscriptionNotRegistered`.

## Step 6: First plan

Open a pull request with a trivial change (for example, a comment in
`live/tenant.hcl`) to trigger the plan workflow. Review the output posted on the
PR.

## Step 7: First apply

The foundation is applied deliberately, not on merge. It creates the management
group hierarchy at tenant-root scope, the highest blast radius operation in the
repository, so a push to main never applies it. After the plan on the PR is
reviewed and the PR is merged, trigger the foundation by hand: open the Actions
tab, select `apply-foundation`, Run workflow on `main` (or
`gh workflow run apply-foundation.yml`). Approve the deployment on the run's page
to release it.

Expect the first apply to take sixty to ninety minutes due to policy
propagation.

Once the foundation is in place, routine lower-scope workloads apply
automatically: merging a PR that touches `live/platform/connectivity/**` or
`live/landingzones/**` (for example the connectivity hub, or a landing zone
onboarded later) runs the `apply` workflow on the push to main. The
foundation, under `live/platform/management/**`, is excluded from that
auto-apply by design.

## Step 8: Remediate the AMBA policies

The foundation apply assigns the AMBA policies and creates the AMBA identity, but
it does not deploy the alerts or the action group. Those are created by the
policies' `DeployIfNotExists` effect, which does not run automatically for scopes
that already exist, so remediation must be triggered once after the apply (and
again as batches of new resources are added, until it is automated).

The action group is the first target: until it exists, alerts have nowhere to
route. Remediate `Deploy-AMBA-Notification` first, then the rest. The simplest
route is the portal: Policy, Assignments, select each `Deploy-AMBA-*`, Create
remediation task. Three things to know if you script it with the CLI instead:

- Remediation runs at subscription scope, not management-group scope
  (`ReEvaluateCompliance` is rejected at MG scope). Set the subscription context
  and pass the MG-level assignment id.
- The AMBA assignments are initiatives, so remediation needs a
  `--definition-reference-id` for the specific policy in the initiative (for the
  action group, the `ALZ_AlertProcessing_Rule` reference in `Notification-Assets`).
- Non-compliance is attributed to the highest assignment in the tree (the
  intermediate root `alz`), so remediate that assignment, not the per-MG ones.

Confirm success: the action group `ag-AMBA-management-ALZ-001` appears in
`rg-amba-<region>` in the management subscription, with the onboarding email as
its receiver. Per-resource alerts deploy as the matching resources are created.

Automating this (a scheduled remediation job or a pipeline step) is the intended
end state; until then it is a manual post-apply step.

## Step 9: Drift detection (automatic)

Nothing to do; it is on by default. `.github/workflows/drift.yml` runs daily
(and can be dispatched from the Actions tab) and checks every stack against the
tenant with the plan (Reader) identity. A stack that no longer matches its
committed configuration opens a GitHub Issue labelled `drift`, refreshed on each
run and closed automatically when the stack comes back clean. Triage those issues
as they appear: either reconcile the tenant by applying, or update the
configuration to match an intended out-of-band change.

Two things to know:

- The foundation is applied by hand (`apply-foundation`), so a foundation drift
  issue may be a merged but not yet applied change rather than a tenant change.
  The issue says so. Check whether the latest foundation commit has been applied
  before treating it as drift.
- Drift detection needs the bootstrap's drift federated credential. It exists for
  any customer bootstrapped with `nrit-azure-pipelines` v0.4.2 or later. For an
  earlier customer, re-run the bootstrap once (step 1); it adds only the new
  credential.
