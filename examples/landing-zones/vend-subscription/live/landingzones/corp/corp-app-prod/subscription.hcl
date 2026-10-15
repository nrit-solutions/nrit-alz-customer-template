# subscription.hcl
#
# The landing zone subscription. The lz-vending unit creates it, so its id is
# not known until that unit has applied. Until then the all-zero id keeps the
# tree valid; the spoke network unit must not be added before the id is in.
#
# After the first apply of _global/lz-vending, read the subscription id from
# its plan output or the portal and put it here, then add the network unit.

locals {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}
