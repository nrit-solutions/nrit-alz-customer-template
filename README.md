# nrit-alz-customer-template

A GitHub template repository. The bootstrap generates a new customer
infrastructure-live repository from it, one per customer. Each generated
repository holds the Terragrunt configuration for a Cloud Adoption Framework
landing zone under `live/`. The tf-pr-ops comment-ops engine operates it from
the public repository `nrit-solutions/tf-pr-ops`: plan and apply run from pull
request comments, and a daily job reports drift.

This is the only repository that ends up in customer hands. The engine source
and the bootstrap that creates the backend, identities, and runner are separate
repositories that stay with the platform operator. Each job installs the engine
runtime of the pinned release from the public repository, so no engine
credential is needed. `/apply` needs a license in the repository variables
`TFPR_LICENSE` and `TFPR_ENTITLEMENT`, which the bootstrap onboarding script
sets. Without them plan, drift, and `/unlock` still work and `/apply` is
refused; see [License](https://docs.nrit.cloud/operations/license/). Every
unit, foundation and workload alike, is plain Terraform on public Azure
Verified Modules.

Full documentation: [docs.nrit.cloud](https://docs.nrit.cloud/).

## How changes are made

A change is a pull request. Every impacted unit is planned when the PR opens.
Review the plan and the gate output, get the required reviews, and comment
`/apply`. The impacted units apply in dependency order, and the
`tf-pr-ops / merge-gate` check turns green so the PR can merge. See
[Plan and apply](https://docs.nrit.cloud/operations/plan-and-apply/) and the
[Command reference](https://docs.nrit.cloud/reference/commands/).

## Workflows

Five caller workflows in `.github/workflows/` (`tf-pr-ops-pr.yml`,
`tf-pr-ops-unlock.yml`, `tf-pr-ops-review.yml`, `tf-pr-ops.yml`, `drift.yml`)
call the dispatch action and the reusable workflows in
`nrit-solutions/tf-pr-ops` at one pinned tag. The `uses:` ref is the whole pin. Read the current version from those files. Once
the Renovate GitHub App is installed, `.github/renovate.json` opens the bump
pull requests, and the invariants check fails a mix of releases. See
[Versions and upgrades](https://docs.nrit.cloud/reference/versions/).

Two more workflows watch the self-hosted runners. `runner-canary.yml` runs on
a schedule from a GitHub-hosted runner and opens an issue when jobs sit queued
too long. `runner-egress-check.yml` is dispatch-only and reports which
endpoints the plan path can reach from the runner.

## Layout

All deployable infrastructure lives under `live/`, and its folder tree mirrors
the CAF management group hierarchy. See
[The live tree](https://docs.nrit.cloud/anatomy/live-tree/).

```
<customer>-alz-live/
├── README.md, ONBOARDING.md, CHANGELOG.md, LICENSE, mise.toml, projects.yml
├── AGENTS.md, CLAUDE.md         # instructions for AI coding agents
├── .mcp.json                    # MCP servers: Microsoft Learn, Terraform registry
├── .claude/                     # agent skills + what the tooling does (README)
├── .pre-commit-config.yaml      # commit hooks; .tflint.hcl and .checkov.yaml configure them
├── .github/                     # caller and runner workflows, invariants script, PR template, Renovate; CODEOWNERS from the bootstrap
├── policy/                      # conftest policies for the policy gate (ships one .example, none active)
└── live/
    ├── root.hcl                 # backend + providers + shared locals contract
    ├── tenant.hcl               # tenant id (must sit at live/ root)
    ├── customer.hcl             # root MG id, region, business unit, AMBA inbox; written by the bootstrap
    ├── _foundation/             # tenant-wide governance, deployed first
    │   ├── management-resources/#   Log Analytics, DCRs, monitoring identity
    │   ├── landing-zones/       #   MG hierarchy + base policy + subscription placement
    │   └── amba/                #   Azure Monitor Baseline Alerts
    ├── platform/                # connectivity, identity, management, security (MG placeholders)
    ├── landingzones/            # corp, online, local (MG placeholders, onboarded per customer)
    ├── decommissioned/          # Decommissioned MG (placeholder)
    └── sandbox/                 # Sandbox MG (placeholder)
```

Each management group folder has a `README.md` describing what it holds. The
`platform` and `landingzones` children ship as README-only placeholders. A
customer's connectivity hub and landing zones are added into them as new units
after the foundation is in place; see
[Scenarios](https://docs.nrit.cloud/scenarios/).

## The foundation

The `_foundation/` units apply first, in dependency order:
`management-resources`, then `landing-zones`, then `amba`. The `landing-zones`
unit reads the upstream ALZ library at a pinned ref plus the platform policy
library vendored under its `lib/`. The `amba` unit reads the upstream ALZ
library at a pinned ref plus the AMBA library vendored under its `lib/`, whose
`README.md` says how to go back to the upstream ref. See
[The foundation units](https://docs.nrit.cloud/anatomy/foundation-units/).

## Gates

Every plan and every drift plan runs a conftest policy check, a checkov
security scan, and an infracost cost estimate, listed as the `post_plan` steps
in `projects.yml`. They start report-only: `policy/` ships only
`tags.rego.example`, checkov warns without blocking, and infracost reports. See
[Policy, security, and cost gates](https://docs.nrit.cloud/operations/gates/).

## Onboarding

`ONBOARDING.md` is the checklist for standing up a new customer landing zone
from this template.

## Local development

Install the pinned toolchain with `mise install`, then wire up the hooks with
`pre-commit install`. `mise.toml` pins every tool, `pre-commit` and its linters
included, so local runs and CI use the same versions.

On commit the hooks format HCL and Terraform, run tflint and checkov over the
changed units, and check the repository invariants (no generated `backend.tf`,
`providers.tf`, or `context.tf` committed, no state, no stack leaves, no
Terraform outside a unit, every engine caller on the same release). The
`pre-commit` job of `tf-pr-ops-pr.yml` runs the same hooks on the files every
pull request changes and gates the dispatch, so a commit made with
`--no-verify` is caught before any plan runs. The same job warns, without
failing, when a PR changes code but not `CHANGELOG.md`.

This template ships no `.terraform.lock.hcl` files. Onboarding generates them
against the customer's own tree, and the invariants check warns until it has.
To move a provider version later, see
[Provider lock files](https://docs.nrit.cloud/reference/versions/#provider-lock-files).
