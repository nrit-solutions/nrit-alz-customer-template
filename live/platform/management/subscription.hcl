# subscription.hcl
#
# The management subscription. It hosts the shared state backend and the
# management resources (Log Analytics, data collection rules, the AMA identity).
#
# In CI the bootstrap sets the AZURE_SUBSCRIPTION_ID Action variable and the
# reusable workflow exports it, so the placeholder is only used for local runs.
# For a local plan, either export AZURE_SUBSCRIPTION_ID or replace the
# placeholder with the management subscription id.

locals {
  subscription_id = get_env("AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
}
