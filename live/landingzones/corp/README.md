# corp

Management group: **Corp** (id `corp`), child of `landingzones`.

Corp-connected landing zones: workloads with no public ingress by default,
connected to the platform hub. Placeholder until the customer's first corp
subscription is onboarded.

To onboard one, add a named subscription folder here (for example
`corp-workload/`) with:

- `subscription.hcl` — the subscription id
- a placement stack wrapping the catalog `lz-vending` stack, to adopt (or
  vend) the subscription and place it under this management group
- a network stack, under a region folder, wrapping the catalog `lz-network`
  stack for the spoke network peered to the platform hub

See the catalog `lz-network` stack's example and README for the settings a
spoke needs against this template's minimal hub: a `network_security_groups`
entry associated to every subnet (the ALZ policy `Deny-Subnet-Without-Nsg`
denies subnets with none) and `hub_peering_options_tohub = {
use_remote_gateways = false }` if the hub has no VPN/ExpressRoute gateway.
