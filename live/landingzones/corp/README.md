# corp

Management group: **Corp** (id `corp`), child of `landingzones`.

Corp-connected landing zones: workloads with no public ingress by default,
connected to the platform hub. Placeholder until the customer's first corp
subscription is onboarded.

To onboard one, add a named subscription folder here (for example
`corp-workload/`) with:

- `subscription.hcl`: the subscription id, shared by the deployables below.
- an `lz-vending` unit (region-agnostic, under `_global/`) sourcing the catalog
  `lz-vending` stack. It owns the subscription lifecycle only: alias or adoption,
  placement under this management group (`subscription_management_group_id`),
  identities, RBAC, and budgets. It creates no network. Corp versus online is just
  the target management group.
- a spoke network unit, under a region folder, sourcing the catalog
  `lz-network-spoke` stack. It owns all spoke network config (the virtual network,
  subnets, NSGs, route tables, and hub peering) for the spoke peered to the platform
  hub. Apply the connectivity hub and the `lz-vending` unit before this one.

See the catalog `lz-network-spoke` stack's example and README for the settings a
spoke needs: a `network_security_groups` entry associated to every subnet (the ALZ
policy `Deny-Subnet-Without-Nsg` denies subnets with none) and
`hub_peering_options_tohub = { use_remote_gateways = false }` if the hub has no
VPN/ExpressRoute gateway.

## Workload resources

Add common single resources (storage account, key vault, Log Analytics workspace,
user-assigned identity) as their own units under a region folder here, each sourcing
a catalog unit at a pinned `?ref`. See the catalog units for the settings each
resource takes.
