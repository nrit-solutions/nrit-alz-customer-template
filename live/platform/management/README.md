# management

Management group: **Management** (id `management`), child of `platform`.

Subscription folder: `sub-management/`.

The central logging and monitoring resources (the Log Analytics workspace, the
Azure Monitor Agent data collection rules, and the AMA identity) are **not**
deployed from this folder. They are part of the platform foundation and are
created by the `caf-platform-foundation` stack under
`live/tenant/_global/`, because the landing-zones policy assignments reference
them by id and need them to exist first.

`sub-management/` is reserved for any extra management-subscription workloads a
customer adds later (for example a dedicated automation account, a backup
vault, or a monitoring workload), each as its own unit or stack. See
`sub-management/README.md`.
