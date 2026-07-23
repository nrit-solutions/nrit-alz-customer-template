# connectivity

Management group: **Connectivity** (id `connectivity`), child of `platform`.

Placeholder. No hub is provisioned in the template; onboard the connectivity hub
here per customer.

To onboard it, add `subscription.hcl` (the connectivity subscription id) and a hub
networking unit under a region folder (for example `westeurope/hub/`). Like every
unit here it is a `main.tf` on public Azure Verified Modules at a pinned `version`
beside a thin `terragrunt.hcl`: `Azure/avm-res-resources-resourcegroup/azurerm` for
the hub resource group, then
`Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm` for the hub itself.
The hub deploys into the connectivity
subscription, a different subscription from the foundation's management
subscription, so its `subscription.hcl` sets that id explicitly; state still goes to
the shared backend (in the management subscription) over Entra ID.

Also set `connectivity_subscription_id` in
`live/_foundation/landing-zones/main.tf` and re-apply that unit, so the
subscription is placed under this management group. It defaults to empty, which
omits the placement, because a connectivity subscription is optional.

Start from the minimal, low-cost hub (one virtual network, no firewall, bastion,
gateways, private DNS, NAT gateway, or DDoS plan) and turn options on per hub as a
workload needs them. If you enable private DNS zones, also wire the foundation
policy default values in `live/_foundation/landing-zones/main.tf` so the ALZ policy
assignments reference the live resources.
