# nrit-azure-customer-template

Template repository used to generate a new infrastructure-live repository
for each client. The generated repository contains the Terragrunt
configuration that consumes versioned catalog stacks and units, plus the
workflows that call versioned pipelines.

This is the only repository that ends up in client hands. The catalog
(`nrit-terragrunt-catalog`) and the pipelines (`nrit-azure-pipelines`)
remain under NRIT control; template instances are jointly managed.

## Status

The foundation and connectivity are wired end to end. `live/root.hcl` and
`live/tenant.hcl` are in place, the `caf-platform-foundation` stack under
`live/platform/management/westeurope/` and the `caf-connectivity-vwan` hub
under `live/platform/connectivity/westeurope/` consume the pinned catalog
stacks, and the `plan` and `apply` workflows call the pinned pipelines
reusable workflows. The landing-zone folders are placeholders: a customer's
first landing zone is onboarded with the catalog `lz-vending` and `lz-network`
stacks, the same pattern the foundation and connectivity hub use. See
`ONBOARDING.md`.

## Layout

All deployable infrastructure lives under `live/` (the Gruntwork
infrastructure-live convention). Repository meta (docs, workflows, tooling)
stays at the root. Inside `live/`, the folder tree mirrors the CAF management
group hierarchy. Folder names use the management group **IDs**. Subscriptions
sit in a named folder under their management group, then region folders, then
units or workloads.

```
nrit-azure-customer-template/
├── README.md, ONBOARDING.md, CHANGELOG.md, LICENSE, mise.toml
├── .github/                             # consumer workflows (call the pipelines repo)
├── docs/                                # onboarding checklist, runbook, upgrade guide
└── live/
    ├── root.hcl                         # generates backend.tf; exposes shared locals
    ├── tenant.hcl                       # tenant id + root MG id (must sit at live/ root)
    ├── platform/                        # Platform MG
    │   ├── connectivity/                #   Connectivity MG
    │   │   ├── subscription.hcl         #     connectivity subscription
    │   │   └── westeurope/
    │   │       ├── region.hcl
    │   │       └── caf-connectivity-hub/ # vWAN hub + firewall
    │   ├── identity/                    #   Identity MG (no subscription in v1)
    │   ├── management/                  #   Management MG
    │   │   ├── subscription.hcl         #     management subscription
    │   │   └── westeurope/
    │   │       ├── region.hcl
    │   │       └── caf-platform-foundation/ # MG hierarchy + policy + management resources
    │   └── security/                    #   Security MG (no subscription in v1)
    ├── landingzones/                    # Landing Zones MG (placeholder)
    │   ├── corp/                        #   Corp MG: onboard with lz-vending + lz-network
    │   └── online/                      #   Online MG: onboard with lz-vending + lz-network
    ├── decommissioned/                  # Decommissioned MG (no subscriptions)
    └── sandbox/                         # Sandbox MG (no subscriptions)
```

Each management group folder has a `README.md` describing the MG and what it
holds. The MG hierarchy itself is created by the `caf-platform-foundation`
stack under `live/platform/management/westeurope/`, deployed once at
tenant-root scope.

## Onboarding

See `ONBOARDING.md` for the step-by-step flow to generate and configure a
new client repository from this template.

## Local development

Install the pinned toolchain with `mise install`. See `mise.toml`.
