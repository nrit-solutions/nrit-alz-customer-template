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

- `live/tenant/_global/caf-platform-foundation/terragrunt.stack.hcl`: set
  `customer_name` (short, lowercase) in the `locals` block. Set
  `subscription_placement` if you are placing subscriptions into management
  groups in this first apply.
- `live/platform/connectivity/.../caf-connectivity-hub/terragrunt.stack.hcl`:
  set `customer_name` to match.
- `live/platform/connectivity/.../caf-connectivity-hub/subscription.hcl`: set
  the connectivity subscription id (the hub deploys there, a different
  subscription from the foundation's management subscription).

Region defaults to `westeurope`; change `live/**/region.hcl` only if the
customer specifies otherwise.

The backend names are never edited here. They come from the `BACKEND_*` Action
variables the bootstrap set. All subscriptions share that one state account
(in the management subscription, where the bootstrap puts the state, runners,
and identities), accessed by Entra ID; each folder's `subscription.hcl` is only
the deploy target, not the state location.

The connectivity hub ships as the minimal validated config (firewall on, DDoS
and private DNS off). To have the foundation policy assignments reference a live
DDoS plan and private DNS, turn those on in the connectivity stack and set
`connectivity_subscription_id` plus the DDoS/DNS names in the foundation stack.

## Step 3: Pin catalog and pipelines versions

Update `catalog_ref` in each `terragrunt.stack.hcl` and the `@v<version>` ref on
each reusable workflow in `.github/workflows/`. The workflow ref must match the
tag the bootstrap pinned the federated credential to (its `pipelines_ref`,
default `v0.1.5`), or OIDC login fails.

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
subscription. The connectivity subscription needs at least `Microsoft.Network`:

```sh
az provider register --namespace Microsoft.Network --subscription <connectivity-sub-id>
```

Register any further providers a workload uses (for example `Microsoft.Web` or
`Microsoft.Sql`) on its landing zone subscription the same way. Without this the
first plan fails at `terraform init` with an authorization error on
`Microsoft.X/register/action`.

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
automatically: merging a PR that touches `live/platform/**` (for example the
connectivity hub) runs the `apply` workflow on the push to main. The foundation,
under `live/tenant/**`, is excluded from that auto-apply by design.
