# local

Management group: **Local** (id `local`), child of `landingzones`.

Created by the architecture definition in
`live/_foundation/landing-zones/lib/architecture_definitions/`, the same as `corp`
and `online`. It comes from the stock ALZ hierarchy and carries the `local`
archetype, whose single assignment is `Enforce-ALDO-Services` (Azure Local
disconnected operations). It is the home for Azure Local landing zones.

Most customers never use it. The management group is still created, because the
ALZ module needs a complete architecture and the NRIT library is the stock
hierarchy plus one line; see `live/_foundation/landing-zones/lib/README.md`. This
folder exists so every management group in the architecture has one.

Onboard a subscription here the same way as `corp` (see `../corp/README.md`): a
`subscription.hcl`, an `lz-vending` unit for subscription lifecycle and placement
(`subscription_management_group_id = "local"`), and a network unit per region.
