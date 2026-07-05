# management

Management group: **Management** (id `management`), child of `platform`.

Holds the management subscription (`subscription.hcl`) and its deployables,
one region folder per region:

- `westeurope/caf-platform-foundation/` — the platform foundation: the CAF
  management group hierarchy, policy, and the management resources (the Log
  Analytics workspace, the Azure Monitor Agent data collection rules, and the
  AMA identity). Deployed once, from here, because the landing-zones policy
  assignments reference the management resources by id and need them to exist
  first. It can also centrally place the connectivity and management
  subscriptions into their management groups (`subscription_placement`).

Add any extra management-subscription workloads a customer needs later (for
example a dedicated automation account, a backup vault, or a monitoring
workload) as their own unit or stack under a region folder here, the same way
`caf-platform-foundation` is laid out.
