# connectivity

Management group: **Connectivity** (id `connectivity`), child of `platform`.

Placeholder. No hub is provisioned in the template; onboard the connectivity hub
here per customer.

To onboard it, add `subscription.hcl` (the connectivity subscription id) and a hub
networking unit under a region folder (for example `westeurope/hub/`), sourcing the
catalog or Azure Verified Modules directly. The hub deploys into the connectivity
subscription, a different subscription from the foundation's management
subscription, so its `subscription.hcl` sets that id explicitly; state still goes to
the shared backend (in the management subscription) over Entra ID.

Start from the minimal, low-cost hub (one virtual network, no firewall, bastion,
gateways, private DNS, NAT gateway, or DDoS plan) and turn options on per hub as a
workload needs them. If you enable private DNS zones, also wire the foundation
policy default values in `live/_foundation/landing-zones/main.tf` so the ALZ policy
assignments reference the live resources.
