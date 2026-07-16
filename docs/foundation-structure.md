# Platform foundation structure

Where the CAF platform foundation lives in the tree, why it sits above the
subscriptions, and how it behaves when you add regions.

## Principle: the foundation is global

The foundation is deployed once for the tenant and creates the hierarchy that
every subscription and workload slots into. It is operated *from* the management
subscription (that is where the deploy identity has tenant rights and where the
state backend lives), but it is not a management-subscription workload and it is
not a per-region workload. So it lives at the top of the tree, not nested under
a subscription or a region.

```
live/
  _foundation/                  # tenant governance, deploy first
    subscription.hcl            # management sub (get_env AZURE_SUBSCRIPTION_ID)
    region.hcl                  # primary region (westeurope)
    landing-zones/              # avm-ptn-alz (base): MGs, base policy, placement
    management-resources/       # avm-ptn-alz-management: Log Analytics, DCRs, AMA identity
    amba/                       # avm-ptn-monitoring-amba-alz + avm-ptn-alz (amba): resources + policy
  platform/
    management/                 # only genuine management-sub, per-region workloads
    connectivity/
    identity/
  landingzones/
```

The `_` prefix sorts it first and marks it special. Each leaf is a plain
Terraform classic unit (`main.tf` plus `terragrunt.hcl`); Terragrunt generates
the backend and providers and pins the subscription. See
[leaf-data-sharing.md](leaf-data-sharing.md) for how the leaves reference each
other.

## Global versus regional, and what `location` means

Every foundation module requires a `location`, but it means two different
things, and that is the whole reason the foundation stays single:

| Leaf | Module | location is | Per region? |
|---|---|---|---|
| landing-zones | avm-ptn-alz (base) | only the region for the policy managed identities; the MGs are global | no |
| amba (policy half) | avm-ptn-alz (amba) | only the region for the AMBA policy identities | no |
| management-resources | avm-ptn-alz-management | the real home of the Log Analytics workspace and DCRs | choice |
| amba (resources half) | avm-ptn-monitoring-amba-alz | the real home of the AMBA resource group and identity | no, singleton |

Where location is nominal (the two policy modules), the region is just a primary
you pin once. Where location is real (the workspace), region is a genuine choice
that only matters for multi-region.

## Multi-region: Variant A, one central workspace (chosen)

A foundation does not multiply per region. What multiplies is connectivity (a
hub per region) and the landing-zone workloads (spokes per region). With a
single central management workspace, which is the ALZ single-pane default, the
entire foundation stays one deployment. Adding a region does not touch
`_foundation/` at all.

```
live/
  _foundation/                  # SINGLE. unchanged when a region is added
    subscription.hcl
    region.hcl                  # westeurope: real home of the LAW, nominal for identities
    landing-zones/
    management-resources/       # one central Log Analytics workspace + DCRs + AMA identity
    amba/                       # one AMBA resource group + identity + policy
  platform/
    connectivity/
      subscription.hcl
      westeurope/
        region.hcl
        hub/                    # hub network, West Europe
      northeurope/
        region.hcl
        hub/                    # hub network, North Europe
  landingzones/
    corp/<workload>/
      westeurope/ ...
      northeurope/ ...
```

To add North Europe you add `connectivity/northeurope/hub/` and the workload
spokes. You do not add anything under `_foundation/`. The AMBA alerts still land
in the new region, because the AMBA policy's `deployIfNotExists` deploys them
wherever the target resources are; you never deploy AMBA per region.

## When you would not use Variant A

Only data residency or a deliberate per-region workspace changes this. If EU and
US logs cannot co-mingle, the governance (`landing-zones`, `amba` policy) stays
global in `_foundation/`, but the workspace moves down to a per-region folder
under `platform/management/<region>/management-resources/`, and the AMA policy in
`_foundation/` points at the primary region's workspace. That is a heavier shape
with cross-tree references, so only adopt it when residency requires it. For a
standard multi-region estate built for resilience, Variant A is correct.

## Why this shape

- **WAF Reliability**: adding a region touches only connectivity and workloads,
  so the governance layer has no blast radius from a region rollout.
- **WAF Operational Excellence**: one management group hierarchy, one policy set,
  one workspace. Nothing to keep consistent across region copies.
- **WAF Cost Optimization**: a single central workspace avoids duplicating
  ingestion and retention per region.

## Deploy order

`_foundation/` first (the management groups must exist before anything is placed
into them), then `platform/` (connectivity hubs), then `landingzones/`. Within
`_foundation/`, the leaf order is management-resources, then landing-zones (its
policy references the workspace), then amba. Terragrunt enforces the leaf order
with the `dependencies` blocks in each `terragrunt.hcl`.
