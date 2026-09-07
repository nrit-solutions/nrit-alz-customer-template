# corp

Management group: **Corp** (id `corp`), child of `landingzones`.

Corp-connected landing zones: workloads with no public ingress by default,
connected to the platform hub. Placeholder until the customer's first corp
subscription is onboarded.

Units here follow the same shape as the foundation: a `main.tf` calling public
Azure Verified Modules at a pinned `version`, beside a thin `terragrunt.hcl` that
only generates the backend and providers and declares apply order. Nothing is
sourced from a private repository.

To onboard a subscription, add a subscription folder here named after the
subscription it maps to, `<archetype>-<purpose>-<environment>` (for example
`corp-payments-prod/`; the environment segment uses the same vocabulary as the
`env` tag, `prod`, `staging`, `dev`), with:

- `subscription.hcl`: the subscription id, shared by the deployables below.
- an `lz-vending` unit (region-agnostic, so under `_global/` with its own
  co-located `region.hcl`) calling `Azure/avm-ptn-alz-sub-vending/azure` version
  `0.2.1`. It owns the subscription lifecycle only: alias or adoption, placement
  under this management group (`subscription_management_group_id = "corp"`),
  identities, RBAC, and budgets. It creates no network. Corp versus online is just
  the target management group.
- a spoke network unit, under a region folder, calling the same
  `Azure/avm-ptn-alz-sub-vending/azure` module with every subscription-level input
  switched off (`subscription_alias_enabled`, `subscription_update_existing`,
  `subscription_management_group_association_enabled` all `false`) so it never
  contends with the `lz-vending` unit. It owns the virtual network, subnets, NSGs,
  route tables, and hub peering. Apply the connectivity hub and the `lz-vending`
  unit before this one.

Two settings the spoke needs: a `network_security_groups` entry associated to
every subnet (the ALZ policy `Deny-Subnet-Without-Nsg` denies subnets with none),
and `hub_peering_options_tohub = { use_remote_gateways = false }` if the hub has
no VPN or ExpressRoute gateway. Set `tags` on the virtual network explicitly to
match the resource group, or the ALZ inherit-tag policy makes it drift every plan.

## Workload resources

Add common single resources (storage account, key vault, Log Analytics workspace,
user-assigned identity) as their own units under a region folder here, each
calling the matching `Azure/avm-res-*` module at a pinned `version`.
