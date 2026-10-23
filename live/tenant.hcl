# tenant.hcl
#
# Tenant-wide values for this customer. Sits at the live/ root so
# find_in_parent_folders("tenant.hcl") resolves from every scope below it
# (find_in_parent_folders only walks ancestors, so this file must be an
# ancestor of all of them).
#
# This value feeds root.hcl, which exposes it to every unit. In CI the
# bootstrap sets the AZURE_TENANT_ID Action variable and the reusable workflow
# exports it, so the placeholder is only used for local runs. For a local plan,
# either export AZURE_TENANT_ID or replace the placeholder. The management group
# the hierarchy is created under is tenant_root_id in customer.hcl.

locals {
  # Entra ID tenant the deployment authenticates against.
  tenant_id = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")
}
