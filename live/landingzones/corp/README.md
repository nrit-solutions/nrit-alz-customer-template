# corp

Management group: **Corp** (id `corp`), child of `landingzones`.

Corp-connected landing zones: workloads with no public ingress by default,
connected to the platform hub. Placeholder until the customer's first corp
subscription is onboarded.

A landing zone is a subscription folder here, named after the subscription it
maps to, `<archetype>-<purpose>-<environment>` (for example
`corp-payments-prod/`). The environment segment uses the `env` tag values:
`prod`, `staging`, `dev`. The folder holds a `subscription.hcl`, an `env.hcl`
with that environment, an `_global/lz-vending/` unit that places the subscription under this management
group (`subscription_management_group_id = "corp"`), and a network unit per
region. Set `tags` on the spoke virtual network to match its resource group,
or the ALZ inherit-tag policy makes it drift on every plan. See
[Onboarding a landing zone](https://docs.nrit.cloud/operations/growing-the-tree/#onboarding-a-landing-zone)
and
[Adding a workload resource](https://docs.nrit.cloud/operations/growing-the-tree/#adding-a-workload-resource).
