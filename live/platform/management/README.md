# management

Management group: **Management** (id `management`), child of `platform`.

The management subscription is where the shared state backend and the deploy
identities live, and it is the subscription the foundation is operated from.

The tenant foundation itself (the CAF management group hierarchy, base policy, and
the management resources: the Log Analytics workspace, the Azure Monitor Agent data
collection rules, and the AMA identity) is not here. It lives in `live/_foundation/`,
deployed once at the top of the tree, because the landing-zones policy assignments
reference the management resources by id and need them to exist first. See
[The foundation units](https://docs.nrit.cloud/anatomy/foundation-units/).

Placeholder otherwise. Add any management-subscription workloads a customer needs
later (for example a dedicated automation account, a backup vault, or a monitoring
workload) as their own unit under a region folder here.
