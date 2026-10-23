# Written once when the repository is created. The repository owns it after that.

locals {
  # Changing it after the first apply moves the whole hierarchy: a migration, not an edit.
  tenant_root_id = "00000000-0000-0000-0000-000000000000"

  location                = "westeurope"
  location_short          = "weu"
  business_unit           = "<short name>"
  amba_action_group_email = "alerts@example.com"
}
