# Example conftest policy for the tf-pr-ops policy gate. Copy this file into a
# `policy/` directory at your repo root (the gate default) and adapt it. It runs
# against `terraform show -json`, which the gate exposes as $TFPR_PLANJSON.
#
# Two patterns here are load-bearing and easy to get wrong:
#   - actions is an ARRAY. A replace is ["delete","create"], an unchanged
#     resource is ["no-op"]. Test membership with `in`, never actions[0].
#   - change.after is null for a destroy. Guard it, or the rule evaluates to
#     undefined and the deny silently fails open instead of firing.
#
# The gate tests the `main` namespace by default, so keep `package main` (or set
# CONFTEST_NAMESPACE to match a different package).
package main

import rego.v1

# Storage accounts that are created or updated must carry an owner tag.
deny contains msg if {
	resource := input.resource_changes[_]
	resource.type == "azurerm_storage_account"
	not "delete" in resource.change.actions
	not "no-op" in resource.change.actions
	resource.change.after != null
	not resource.change.after.tags.owner
	msg := sprintf("%s: azurerm_storage_account must set an 'owner' tag", [resource.address])
}

# Advisory: surface any resource that will be destroyed.
warn contains msg if {
	resource := input.resource_changes[_]
	"delete" in resource.change.actions
	msg := sprintf("%s will be destroyed", [resource.address])
}
