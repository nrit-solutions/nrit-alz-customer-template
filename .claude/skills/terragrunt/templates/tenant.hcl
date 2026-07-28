# tenant.hcl — tenant-wide vars (Azure ALZ/CAF). Sits at the live/ repo root so
# find_in_parent_folders("tenant.hcl") resolves from every scope below it
# (find_in_parent_folders only walks ancestors, so this must be an ancestor of
# all deployables). Read by root.hcl, which exposes the values to every unit.
#
# In CI the bootstrap sets the AZURE_TENANT_ID Action variable and the reusable
# workflow exports it, so the placeholder is only used for local runs. For a
# local plan, either export AZURE_TENANT_ID or replace the placeholder.

locals {
  # Entra ID tenant the deployment authenticates against.
  tenant_id = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")

  # Management group the ALZ hierarchy is created under. Defaults to the tenant
  # root group (its id equals the tenant id). Set to an existing intermediate
  # management group id if the customer already has one.
  tenant_root_id = local.tenant_id
}
