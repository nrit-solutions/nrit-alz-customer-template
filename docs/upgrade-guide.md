# Upgrade guide

How to upgrade the versions this repository pins. There are no catalog stacks and
no `catalog_version` local. Three things carry pinned versions.

## Public AVM modules

Each unit's `main.tf` sources an Azure Verified Module with an explicit `version`.
To upgrade, change the `version` argument, open a PR, and review the plan.

## The ALZ policy libraries

Two units set `library_references` on the `alz` provider, and a library bump
touches both.

`live/_foundation/landing-zones/terragrunt.hcl` has two entries:

- `{ path = "platform/alz", ref = "2026.04.2" }`, the upstream ALZ library. Bump
  the `ref` to upgrade.
- `{ custom_url = ".../lib" }`, the NRIT library vendored at
  `live/_foundation/landing-zones/lib/`. It has no `ref`. It lives in this repo,
  so you edit it in place.

`live/_foundation/amba/terragrunt.hcl` has two entries with refs:
`{ path = "platform/alz", ref = "2026.04.2" }` and
`{ path = "platform/amba", ref = "2026.06.2" }`. Keep the `platform/alz` ref the
same in both units.

### Re-sync the vendored architecture after a platform/alz bump

`lib/architecture_definitions/nrit.alz_architecture_definition.json` is a full
copy of the stock `alz` architecture plus one line: the `nrit_tags` archetype on
the intermediate root. The module needs a complete architecture, so the whole
hierarchy is duplicated there.

When you bump the `platform/alz` ref, diff that file against the stock `alz`
architecture at the new version, apply any hierarchy changes, and keep
`nrit_tags` on the root. Nothing tracks this automatically. See
`live/_foundation/landing-zones/lib/README.md`.

## The engine

The comment-ops engine is consumed as a reusable workflow, not vendored. The two
workflows in `.github/workflows/` pin `nrit-tf-pr-ops` at `@v1.3.0` with a matching
`engine_ref: v1.3.0`. To move to a new engine release, bump both pins together (the
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
