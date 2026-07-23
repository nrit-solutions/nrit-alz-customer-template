# platform

Management group: **Platform** (id `platform`), child of `alz`.

Holds the platform subscriptions that run shared services for the whole
landing zone. Child management groups:

- `connectivity` for hub networking
- `identity` for identity services
- `management` for logging, monitoring, automation
- `security` for security tooling

Each child MG with a subscription holds `subscription.hcl` (and, per region,
`region.hcl`) directly, for example `connectivity/subscription.hcl` and
`connectivity/westeurope/`. A child MG with no subscription yet holds only a
README until one is provisioned.
