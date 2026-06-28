# connectivity

Management group: **Connectivity** (id `connectivity`), child of `platform`.

Subscription folder: `sub-connectivity/`. Holds the hub networking stack
(`caf-connectivity-hub`) under `sub-connectivity/westeurope/`.

The hub is wired to the catalog `caf-connectivity-vwan` stack: a single-region
Virtual WAN with Azure Firewall, deployed into the connectivity subscription.
It deploys to a different subscription from the foundation, so its
`subscription.hcl` sets the connectivity subscription id explicitly; state still
goes to the shared backend (the bootstrap subscription) over Entra ID.

The committed default is the minimal validated hub (firewall on, DDoS and
private DNS off). Turn DDoS, private DNS, gateways, and bastion on in the
stack's `primary_hub` / `virtual_wan_settings` blocks as needed. If you enable
the DDoS plan and private DNS, also wire the foundation policy default values
(see `live/tenant/_global/caf-platform-foundation/terragrunt.stack.hcl`) so the
ALZ policy assignments reference the live resources.

To use a hub virtual network instead of Virtual WAN, point the stack at the
catalog `caf-connectivity-hub-and-spoke` stack instead.
