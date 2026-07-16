# subscription.hcl
#
# The foundation is operated from the management subscription: that is where the
# deploy identity has tenant-root rights and where the state backend lives. The
# management groups and policy it deploys are tenant-scoped, not resources in
# this subscription, but every leaf still authenticates against it.
#
# In CI the bootstrap sets the AZURE_SUBSCRIPTION_ID Action variable and the
# reusable workflow exports it, so the placeholder is only used for local runs.

locals {
  subscription_id = get_env("AZURE_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
}
