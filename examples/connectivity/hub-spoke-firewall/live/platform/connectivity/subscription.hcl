# subscription.hcl
#
# The connectivity subscription. The hub deploys here, which is a different
# subscription from the management subscription that holds the shared state
# backend. root.hcl reads the backend subscription from AZURE_SUBSCRIPTION_ID
# and this file for the deploy target, so the id is set explicitly.
#
# Replace with the customer's connectivity subscription id.

locals {
  subscription_id = "00000000-0000-0000-0000-000000000000"
}
