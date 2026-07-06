# corp

Management group: **Corp** (id `corp`), child of `landingzones`.

Corp-connected landing zones: workloads with no public ingress by default,
connected to the platform hub. Placeholder until the customer's first corp
subscription is onboarded.

To onboard one, add a named subscription folder here (for example
`corp-workload/`) with:

- `subscription.hcl`: the subscription id
- a placement stack wrapping the catalog `lz-vending` stack. It owns the
  subscription lifecycle only: alias or adoption, placement under this
  management group (`subscription_management_group_id`), identities, RBAC, and
  budgets. It creates no network. Corp versus online is just the target
  management group.
- a network stack, under a region folder, wrapping the catalog `lz-network`
  stack. It owns all spoke network config (the virtual network, subnets, NSGs,
  route tables, and hub peering) for the spoke peered to the platform hub.

Both stacks forward their whole values map to their single unit, so the module
inputs are set directly. See the catalog `lz-network` stack's example and README
for the settings a spoke needs against this template's minimal hub: a
`network_security_groups` entry associated to every subnet (the ALZ policy
`Deny-Subnet-Without-Nsg` denies subnets with none) and `hub_peering_options_tohub
= { use_remote_gateways = false }` if the hub has no VPN/ExpressRoute gateway.
Subscription-level keys are reserved in `lz-network` and fail loudly by design;
set them in the `lz-vending` stack.
