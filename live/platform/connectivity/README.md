# connectivity

Management group: **Connectivity** (id `connectivity`), child of `platform`.

Placeholder. The template ships no hub; onboard the connectivity hub here per
customer: a `subscription.hcl` with the connectivity subscription id, an
`env.hcl`, a region folder with its own `region.hcl`, and a hub unit inside it.
`root.hcl` reads an `env.hcl` and a `region.hcl` from every unit, so both files
are required. See
[Onboarding a connectivity hub](https://docs.nrit.cloud/operations/growing-the-tree/#onboarding-a-connectivity-hub).

Also set `connectivity_subscription_id` in
`live/_foundation/landing-zones/main.tf` and re-apply that unit, so the
subscription is placed under this management group. It defaults to empty,
because a connectivity subscription is optional.
