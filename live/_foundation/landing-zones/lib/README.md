# NRIT platform ALZ library

Custom Azure Landing Zones library, vendored into this repo and read by the `alz`
provider (see `../terragrunt.hcl`, `library_references`). It layers NRIT additions on
top of the stock `platform/alz` library. All assets are JSON, matching the stock ALZ
library (the tooling also accepts YAML if you ever need inline comments).

## Contents

- `architecture_definitions/nrit`: the management group hierarchy the module deploys.
- `archetype_definitions/nrit_tags`: the tag-governance archetype, attached to the root.
- `policy_set_definitions/Enforce-Tag-Governance`: the tag-governance initiative.
- `policy_definitions/Deny-Tag-NotAllowedValues`: a custom deny-on-tag-value policy.
- `policy_assignments/Enforce-Tag-Gov`: the assignment placed by `nrit_tags`.

## The nrit architecture

This library defines exactly one architecture, named `nrit`. That name is the only
valid value for `architecture_name` in `../main.tf`, which is where it is set. You
would change it only if you add a second architecture definition here, or point the
unit at a different library whose architecture is named something else. Adding one
means copying a complete hierarchy: see "stock architecture, unchanged, plus one
line" below.

`nrit.alz_architecture_definition.json` is the **stock `alz` architecture, unchanged,
plus one line**: the `nrit_tags` archetype on the intermediate root (`alz`). The ALZ
module requires a *complete* architecture to deploy any customization, so the whole
hierarchy is duplicated here. There is no "extend the stock architecture in place"
option.

**On a library upgrade:** when you bump the `platform/alz` ref in `../terragrunt.hcl`,
re-sync this file against the stock `alz` architecture at the new version (diff it,
apply any hierarchy changes, keep `nrit_tags` on the root). Nothing here tracks the
stock hierarchy automatically. The only intended NRIT delta is `nrit_tags` on the root.

## Placeholder resource IDs

References between assets (for example the policy set pointing at its definitions) use
a `placeholder` management-group segment in the resource id. alzlib resolves assets by
name only, so the placeholder is rewritten to the real management group at plan time.

## Tag governance

The tag keys follow the Microsoft Cloud Adoption Framework tag examples
(`app`, `env`, `opsteam`, `costcenter`, `businessunit`, `criticality`,
`confidentiality`). Reference:
<https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-tagging>
