# subscription.hcl — per-subscription vars (Azure). On AWS this is account.hcl.
# Place one at each subscription folder. It is the single source of truth for
# the subscription id it declares; every deployable in the sub reads it through
# root.hcl. No cross-stack output reads for the sub id.
#
# tenant_id lives in tenant.hcl (repo root), not here. The state backend coords
# live in the reusable-workflow Action variables (BACKEND_AZURE_*), not here, so
# one shared state account can back every subscription.
#
# In CI the bootstrap sets AZURE_SUBSCRIPTION_ID and the workflow exports it, so
# the placeholder is only used for local runs. For a vended (net-new) sub, the
# id is unknown until the vend applies: vend it in _global/lz-vending first,
# then a second PR writes the returned id here.

locals {
  subscription_id = get_env("AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
}
