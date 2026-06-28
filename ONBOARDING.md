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
   and fill in the tenant, bootstrap subscription, repository name, approvers,
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
(in the bootstrap subscription), accessed by Entra ID; each folder's
`subscription.hcl` is only the deploy target, not the state location.

The connectivity hub ships as the minimal validated config (firewall on, DDoS
and private DNS off). To have the foundation policy assignments reference a live
DDoS plan and private DNS, turn those on in the connectivity stack and set
`connectivity_subscription_id` plus the DDoS/DNS names in the foundation stack.

## Step 3: Pin catalog and pipelines versions

Update `catalog_ref` in each `terragrunt.stack.hcl` and the `@v<version>` ref on
each reusable workflow in `.github/workflows/`. The workflow ref must match the
tag the bootstrap pinned the federated credential to (its `pipelines_ref`,
default `v0.1.0`), or OIDC login fails.

## Step 4: First plan

The plan and apply workflows fetch the catalog stack at its pinned tag. The
catalog repository is private, so the runner needs read access to it: either
make the catalog readable to the customer org's Actions, or supply the runner a
token (a GitHub App installation token or a read-only PAT) configured as a git
credential for `github.com/nrit-solutions`. Without it `terragrunt stack
generate` cannot clone the catalog.

Open a pull request with a trivial change (for example, a comment in
`live/tenant.hcl`) to trigger the plan workflow. Review the output posted on the
PR.

## Step 5: First apply

After review and approval by the approver team, merge the PR. The apply workflow
runs and provisions the foundation stack.

Expect the first apply to take sixty to ninety minutes due to policy
propagation.
