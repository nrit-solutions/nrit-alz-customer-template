# online

Management group: **Online** (id `online`), child of `landingzones`.

Internet-facing landing zones. Placeholder until the customer's first online
subscription is onboarded, the same way as `corp` (see `../corp/README.md`):
a `subscription.hcl`, a `lz-vending` placement stack (subscription lifecycle
only), and a `lz-network` spoke network stack (all spoke network config). Corp
versus online is just the target management group set in the `lz-vending` stack.
