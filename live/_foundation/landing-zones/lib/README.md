# Platform ALZ library

The custom Azure Landing Zones library for the `landing-zones` unit. The `alz`
provider reads it next to the stock `platform/alz` library (see
`library_references` in `../terragrunt.hcl`). All assets are JSON, like the
stock library. The tooling also accepts YAML if you need inline comments.

## Contents

- `architecture_definitions/baseline`: the management group hierarchy. It is
  the stock `alz` architecture with `baseline_root` in place of `root` and the
  `baseline_tags` archetype added on the root.
- `archetype_definitions/baseline_root`: an override of the stock `root` archetype
  that removes `Deploy-SvcHealth-BuiltIn`. The `amba` unit's
  `Deploy-AMBA-Res-SvcHlth` deploys the same built-in Service Health policy, so
  keeping both would create duplicate alert rules and action groups.
- `archetype_definitions/baseline_tags`: the tag-governance archetype.
- `policy_set_definitions/Enforce-Tag-Governance`: the tag-governance initiative.
- `policy_definitions/Deny-Tag-NotAllowedValues`: a custom deny-on-tag-value policy.
- `policy_assignments/Enforce-Tag-Gov`: the assignment placed by `baseline_tags`.

## On a library upgrade

When you bump the `platform/alz` ref in `../terragrunt.hcl`, resync the
`baseline` architecture against the stock `alz` architecture at the new
version. Apply any hierarchy changes and keep `baseline_root` and `baseline_tags` on the root.
Nothing tracks the stock hierarchy automatically.

How the library works, and how to add a policy:
[Vendored policy library](https://docs.nrit.cloud/anatomy/policy-library/).
