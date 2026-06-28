# subscription.hcl
#
# The connectivity subscription. The Virtual WAN, the hub, and the firewall
# deploy here. This is a different subscription from the foundation's
# management subscription, so the id is set explicitly: AZURE_SUBSCRIPTION_ID
# is the bootstrap (state) subscription used for the shared backend, not this
# deploy target.
#
# Set this to the customer's connectivity subscription id during onboarding.

locals {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}
