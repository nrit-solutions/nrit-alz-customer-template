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

In the generated repository, edit:

- `tenant.hcl` (at the `live/` root): tenant ID, root management group ID,
  customer name
- Each `live/**/subscription.hcl`: subscription ID and name
- Each `live/**/region.hcl`: typically left as `westeurope` unless the customer
  specifies otherwise

The backend names are not edited here. They come from the `BACKEND_*` Action
variables the bootstrap set, which the pipeline injects at run time.

## Step 3: Pin catalog and pipelines versions

Update the `?ref=` parameters in each `terragrunt.stack.hcl` and the `@v<major>`
parameters in each workflow.

## Step 4: First plan

Open a pull request with a trivial change (for example, a comment in
`tenant.hcl`) to trigger the plan workflow. Review the output posted on the PR.

## Step 5: First apply

After review and approval by the approver team, merge the PR. The apply workflow
runs and provisions the foundation stack.

Expect the first apply to take sixty to ninety minutes due to policy
propagation.
