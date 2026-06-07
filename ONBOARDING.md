# Onboarding checklist

This document walks through onboarding a new client to NRIT's Azure platform
delivery.

## Prerequisites

- Azure tenant (existing or newly created)
- Owner permission at the tenant root, granted to the principal performing
  onboarding
- GitHub organisation (or Azure DevOps organisation) for the client
  repository
- A point of contact at the client for identity and networking decisions

## Step 1: Generate the repository

1. Use the GitHub template-repo feature on `nrit-azure-customer-template` to
   create a new repository.
2. Clone the repository locally.

## Step 2: Replace placeholders

Edit the following files with the client's specifics:

- `live/tenant/tenant.hcl`: tenant ID, root management group ID, client name
- Each `live/**/subscription.hcl`: subscription ID and name
- Each `live/**/region.hcl`: typically left as `westeurope` unless the client
  specifies otherwise
- `live/root.hcl`: update the `Repo` tag and the optional `TF_STATE_PREFIX`
  environment variable handling

## Step 3: Bootstrap state storage

(Run from a workstation with Owner access to the tenant.)

```bash
./scripts/bootstrap-state.sh <client-short-name>
```

This creates a resource group, storage account, and container per
subscription.

## Step 4: Configure OIDC federation

(Detailed steps in `docs/oidc-setup.md` in the pipelines repository.)

## Step 5: Pin catalog and pipelines versions

Update the `?ref=` parameters in each `terragrunt.stack.hcl` and the
`@v<major>` parameters in each workflow.

## Step 6: First plan

Open a pull request with a trivial change (for example, a comment in
`live/tenant/tenant.hcl`) to trigger the plan workflow. Review the output.

## Step 7: First apply

After review and approval, merge the PR. The apply workflow runs and
provisions the foundation stack.

Expect the first apply to take sixty to ninety minutes due to policy
propagation.
