# tenant.hcl
#
# Tenant-wide values for this customer. Sits at the live/ root so
# find_in_parent_folders("tenant.hcl") resolves from every scope below it
# (find_in_parent_folders only walks ancestors, so this file must be an
# ancestor of all of them).
#
# These two values feed root.hcl, which exposes them to every unit. In CI the
# bootstrap sets the AZURE_TENANT_ID Action variable and the reusable workflow
# exports it, so the placeholder is only used for local runs. For a local plan,
# either export AZURE_TENANT_ID or replace the placeholder.

locals {
  # Entra ID tenant the deployment authenticates against.
  tenant_id = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")

  # Management group the ALZ hierarchy is created under. It becomes
  # parent_resource_id on the management group module in
  # _foundation/landing-zones. Defaults to the tenant root group (its id equals
  # the tenant id), so leaving it alone creates the hierarchy at tenant root.
  #
  # If the customer already has an intermediate management group, set this to
  # that group's id (the plain name, not the full resource id) before the first
  # apply. The group must already exist; this repository does not create it.
  #
  # Changing it after the first apply moves the whole ALZ hierarchy to a new
  # parent. That is destructive: policy assignment scopes and role assignments
  # follow the move, and subscriptions can be left unplaced while it runs. Treat
  # it as a migration, not an edit.
  tenant_root_id = local.tenant_id
}
