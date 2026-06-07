# platform

Management group: **Platform** (id `platform`), child of `alz`.

Holds the platform subscriptions that run shared services for the whole
landing zone. Child management groups:

- `connectivity` — hub networking
- `identity` — identity services
- `management` — logging, monitoring, automation
- `security` — security tooling

Subscriptions live in a named folder under each child MG, for example
`connectivity/sub-connectivity/`.
