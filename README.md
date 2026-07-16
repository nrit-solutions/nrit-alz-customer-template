# nrit-alz-customer-template

A GitHub template repository. The bootstrap generates a new customer
infrastructure-live repository from it, one per customer. Each generated
repository holds the Terragrunt configuration for a Cloud Adoption Framework
landing zone under `live/`, and it is operated by the `nrit-tf-pr-ops`
comment-ops engine consumed as a reusable workflow: plan and apply run from pull
request comments, and a daily job reports drift.

This is the only repository that ends up in customer hands. The comment-ops
engine (`nrit-tf-pr-ops`), the private module and policy catalog
(`nrit-terragrunt-catalog`), and the bootstrap that creates the backend,
identities, and runner (`nrit-alz-bootstrap`) stay separate repositories under
NRIT control. A generated repository consumes the engine and the catalog at
pinned versions and is created by the bootstrap.

## How changes are made

A change is a pull request:

1. Open a PR touching a unit. Every impacted unit is planned automatically.
2. Review the plan posted as a comment, including the policy, security, and cost
   gate output.
3. Comment `/apply` to apply the changed units in dependency order, after the
   required approvals.
4. The `terraform-pr-ops / merge-gate` check goes green once applied, and the PR
   merges.

The engine is not stored here. The two workflows in `.github/workflows/` call the
`nrit-tf-pr-ops` reusable workflows, pinned `@v1`. Vendoring the engine into the
repository is a documented escape hatch for a fully self-contained repository; see
`ONBOARDING.md`.

## Layout

All deployable infrastructure lives under `live/` (the Gruntwork
infrastructure-live convention). Repository meta (docs, workflows, tooling) stays
at the root. Inside `live/`, the folder tree mirrors the CAF management group
hierarchy; folder names are the management group IDs. A subscription sits in a
named folder under its management group, then region folders, then units (a folder
with a `terragrunt.hcl`).

```
<customer>-alz-live/
├── README.md, ONBOARDING.md, CHANGELOG.md, LICENSE, mise.toml
├── .github/                     # caller workflows (call the nrit-tf-pr-ops engine)
├── policy/                      # active conftest policies (the policy gate)
├── docs/                        # foundation structure, data sharing, gates, runbook
└── live/
    ├── root.hcl                 # backend + providers + shared locals contract
    ├── tenant.hcl               # tenant id + root MG id (must sit at live/ root)
    ├── _foundation/             # tenant-wide governance, deployed first
    │   ├── management-resources/#   Log Analytics, DCRs, monitoring identity
    │   ├── landing-zones/       #   MG hierarchy + base policy + subscription placement
    │   └── amba/                #   Azure Monitor Baseline Alerts
    ├── platform/                # connectivity, identity, management, security (MG placeholders)
    ├── landingzones/            # corp, online (MG placeholders, onboarded per customer)
    ├── decommissioned/          # Decommissioned MG (placeholder)
    └── sandbox/                 # Sandbox MG (placeholder)
```

Each management group folder has a `README.md` describing what it holds. The MG
hierarchy itself is created by the `_foundation/landing-zones` unit at tenant-root
scope. The `platform` and `landingzones` children ship as README-only placeholders:
a customer's connectivity hub and landing zones are onboarded into them from the
catalog after the foundation is in place.

## The foundation

The `_foundation/` units are deployed first (the underscore sorts them to the top)
and apply in dependency order: `management-resources`, then `landing-zones`, then
`amba`. They use public Azure Verified Modules directly, and the `landing-zones`
unit references a pinned policy library from the private catalog. See
`docs/foundation-structure.md` for the shape and the multi-region decision, and
`docs/leaf-data-sharing.md` for how units share values without reading each other's
outputs.

## Gates

Every plan (and every drift plan) runs a conftest policy check, a checkov security
scan, and an infracost cost estimate. They start advisory. See `docs/policy-gates.md`.

## Onboarding

`ONBOARDING.md` documents the flow for generating and standing up a new customer
landing zone from this template.

## Local development

Install the pinned toolchain with `mise install`. See `mise.toml`.
