# nrit-azure-customer-template

Template repository used to generate a new infrastructure-live repository
for each client. The generated repository contains the Terragrunt
configuration that consumes versioned catalog stacks and units, plus the
workflows that call versioned pipelines.

This is the only repository that ends up in client hands. The catalog
(`nrit-terragrunt-catalog`) and the pipelines (`nrit-azure-pipelines`)
remain under NRIT control; template instances are jointly managed.

## Status

Scaffold only. Folder structure and tooling are in place. No `root.hcl`,
`*.hcl` configuration, or workflows have been written yet.

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
    ├── root.hcl                         # generates provider.tf and backend.tf
    ├── tenant/                          # tenant root config + foundation stack
    │   ├── tenant.hcl
    │   └── _global/
    │       └── caf-platform-foundation/ # builds the MG hierarchy + root policies
    ├── platform/                        # Platform MG
    │   ├── connectivity/                #   Connectivity MG
    │   │   └── sub-connectivity/        #     subscription
    │   │       └── westeurope/caf-connectivity-hub/
    │   ├── identity/                    #   Identity MG (no subscription in v1)
    │   ├── management/                  #   Management MG
    │   │   └── sub-management/
    │   │       └── westeurope/log-analytics-central/
    │   └── security/                    #   Security MG (no subscription in v1)
    ├── landingzones/                    # Landing Zones MG
    │   ├── corp/                        #   Corp MG
    │   │   ├── corp-prd/                #     subscription (prd)
    │   │   │   └── westeurope/workloads/webapp-sql-baseline/
    │   │   └── corp-tst/                #     subscription (tst)
    │   │       └── westeurope/workloads/
    │   └── online/                      #   Online MG
    │       └── online-prd/
    │           └── westeurope/
    ├── decommissioned/                  # Decommissioned MG (no subscriptions)
    └── sandbox/                         # Sandbox MG (no subscriptions)
```

Each management group folder has a `README.md` describing the MG and what it
holds. The MG hierarchy itself is created by the `caf-platform-foundation`
stack under `live/tenant/_global/`, deployed once at tenant-root scope.

## Onboarding

See `ONBOARDING.md` for the step-by-step flow to generate and configure a
new client repository from this template.

## Local development

Install the pinned toolchain with `mise install`. See `mise.toml`.
