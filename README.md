# nrit-alz-customer-template

A GitHub template repository. The bootstrap generates a new customer
infrastructure-live repository from it, one per customer. Each generated
repository holds the Terragrunt configuration for a Cloud Adoption Framework
landing zone under `live/`, and it is operated by the `nrit-tf-pr-ops`
comment-ops engine consumed as a reusable workflow: plan and apply run from pull
request comments, and a daily job reports drift.

This is the only repository that ends up in customer hands. The comment-ops
engine (`nrit-tf-pr-ops`) and the bootstrap that creates the backend, identities,
and runner (`nrit-alz-bootstrap`) stay separate repositories under NRIT control.
A generated repository is created by the bootstrap and consumes the engine at a
pinned version. That is its only dependency on a private NRIT repository. Every
unit, foundation and workload alike, is plain Terraform on public Azure Verified
Modules, and the custom policy library is vendored under
`live/_foundation/landing-zones/lib/`.

## How changes are made

A change is a pull request:

1. Open a PR touching a unit. Every impacted unit is planned automatically.
2. Review the plan posted as a comment, including the policy, security, and cost
   gate output (that panel expands automatically when a gate reports a finding).
3. Comment `/apply` to apply the changed units in dependency order, after the
   required approvals. The engine reacts to your comment as it works: 👀 seen,
   🚀 running, 🎉 done (or 👎 on failure).
4. The `tf-pr-ops / merge-gate` check goes green once applied, and the PR
   merges. It stays red if the PR changed Terraform but no unit was selected, so an
   unapplied new or removed unit cannot merge green.

The engine is not stored here. The two workflows in `.github/workflows/` call the
`nrit-tf-pr-ops` reusable workflows at a pinned tag, matched by the `engine_ref`
input. Read the current version from those two files rather than from prose.
Vendoring the engine into the repository is a documented escape hatch for a fully
self-contained repository; see `ONBOARDING.md`.

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
├── AGENTS.md, CLAUDE.md         # instructions for AI coding agents
├── .mcp.json                    # MCP servers: Microsoft Learn, Terraform registry
├── .claude/                     # agent skills + what the tooling does (README)
├── .pre-commit-config.yaml      # commit hooks; .tflint.hcl and .checkov.yaml configure them
├── .github/                     # caller workflows (engine), changelog + lint checks, hook script
├── policy/                      # active conftest policies (the policy gate)
├── docs/                        # foundation structure, data sharing, gates, upgrades, runbook
└── live/
    ├── root.hcl                 # backend + providers + shared locals contract
    ├── tenant.hcl               # tenant id + root MG id (must sit at live/ root)
    ├── _foundation/             # tenant-wide governance, deployed first
    │   ├── management-resources/#   Log Analytics, DCRs, monitoring identity
    │   ├── landing-zones/       #   MG hierarchy + base policy + subscription placement
    │   └── amba/                #   Azure Monitor Baseline Alerts
    ├── platform/                # connectivity, identity, management, security (MG placeholders)
    ├── landingzones/            # corp, online, local (MG placeholders, onboarded per customer)
    ├── decommissioned/          # Decommissioned MG (placeholder)
    └── sandbox/                 # Sandbox MG (placeholder)
```

Each management group folder has a `README.md` describing what it holds. The MG
hierarchy itself is created by the `_foundation/landing-zones` unit at tenant-root
scope. The `platform` and `landingzones` children ship as README-only placeholders:
a customer's connectivity hub and landing zones are added into them as new units
after the foundation is in place. Each README says which AVM modules that unit
uses.

## The foundation

The `_foundation/` units are deployed first (the underscore sorts them to the top)
and apply in dependency order: `management-resources`, then `landing-zones`, then
`amba`. They use public Azure Verified Modules directly. The `landing-zones` unit reads the
upstream ALZ library at a pinned ref plus the NRIT library vendored under its
`lib/`; `amba` reads the upstream ALZ and AMBA libraries at pinned refs. See
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

Install the pinned toolchain with `mise install`, then wire up the hooks with
`pre-commit install`. `mise.toml` pins every tool involved, `pre-commit` and its
linters included, so local runs and CI use identical versions.

On commit the hooks format HCL and Terraform, run tflint and checkov over the
changed units, and check the repository invariants (no generated `backend.tf`,
`providers.tf`, or `context.tf` committed, no state, no stack leaves, no
Terraform outside a unit). The `lint` workflow runs the same hooks on every pull
request and fails, so a commit made with `--no-verify` is caught there.

Each unit's `.terraform.lock.hcl` is committed once generated, and that is what
actually pins the provider versions; the `~>` constraints in the generated
`providers.tf` only bound them. **This template ships none**: a lock file records
the versions resolved at the moment it is written, so a pre-generated one would
start every customer on whatever resolved the day the template was last touched.
Onboarding step 3 generates them against the customer's own tree, and the
invariants check warns, without blocking, until it has. To move a provider
version afterwards, run
`terragrunt --working-dir live/<unit> init -backend=false -upgrade` and commit
the diff as its own PR.
