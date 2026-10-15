# subscription.hcl
#
# The landing zone subscription. Both the placement unit (_global/lz-vending)
# and the spoke network unit (westeurope/network) read this. It is a different
# subscription from the management subscription that holds the shared state
# backend, so the id is set explicitly.
#
# Replace with the customer's subscription id.

locals {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}
