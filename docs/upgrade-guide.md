# Upgrade guide

How to upgrade the versions this repository pins. There are no catalog stacks and
no `catalog_version` local. Three things carry pinned versions.

## Public AVM modules

Each unit's `main.tf` sources an Azure Verified Module with an explicit `version`.
To upgrade, change the `version` argument, open a PR, and review the plan.

## The catalog policy library

The `landing-zones` unit references the private catalog policy library in
`live/_foundation/landing-zones/terragrunt.hcl` through the `alz` provider's
`library_references`. To upgrade, change the `ref` on each entry.

## The engine

The comment-ops engine is consumed as a reusable workflow, not vendored. The two
workflows in `.github/workflows/` pin `nrit-tf-pr-ops` at `@v1` with a matching
`engine_ref: v1`. To move to a new engine release, bump both pins together (the
`uses:` ref and `engine_ref`) in each caller file. The two must match, or the
engine checkout skews from the reusable-workflow body.

## The process

1. Change the `version`, `ref`, or the caller pins on a branch.
2. Open a PR. The engine plans the impacted units and posts the diff.
3. Review the plan and the gate output.
4. Comment `/apply` after approval.
5. Roll back by reverting the version, ref, or pin change and applying again.

Upgrade one module, library, or the engine at a time so the plan diff stays
readable.
