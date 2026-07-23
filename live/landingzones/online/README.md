# online

Management group: **Online** (id `online`), child of `landingzones`.

Internet-facing landing zones. Placeholder until the customer's first online
subscription is onboarded, the same way as `corp` (see `../corp/README.md`): a
`subscription.hcl`, an `lz-vending` unit (subscription lifecycle only), and a
network unit per region (all spoke network config). Both call
`Azure/avm-ptn-alz-sub-vending/azure`. Corp versus online is just the target
management group set in the `lz-vending` unit.
