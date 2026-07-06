# Upgrade guide

How to upgrade catalog and pipelines versions.

## Catalog

Each `terragrunt.stack.hcl` pins the catalog through a single `catalog_version`
local. It renders both the stack block `?ref` and `values.catalog_ref`, so the
stack and its units always resolve at the same tag; there is no second place to
edit and no way for the two to drift.

1. Bump `catalog_version` in the stack file (for example the foundation, at
   `live/platform/management/westeurope/caf-platform-foundation/terragrunt.stack.hcl`).
2. Open a pull request. The plan workflow renders the diff before anything is
   applied. A new catalog release can change the values contract, so read the
   catalog's CHANGELOG for the target tag and reshape the stack values if needed.
3. Merge and apply (the foundation applies by hand through `apply-foundation`;
   lower-scope stacks apply on merge). Roll back by reverting the
   `catalog_version` change and applying again.

## Pipelines

Update the `@v<version>` ref on each reusable workflow in `.github/workflows/`.
The ref must match the tag the bootstrap pinned the federated credential to, or
OIDC login fails (see ONBOARDING.md, step 3).
