# Conftest governance policy for the tf-pr-ops policy gate. Runs against
# terraform show -json ($TFPR_PLANJSON) on every plan.
#
# Starts advisory: WARN rules only, so findings show in the PR comment / drift
# issue without blocking the merge gate. Promote a rule to `deny` (and drop
# CHECKOV_SOFT_FAIL on the checkov hook) once the tenant is clean and the team
# wants it enforced. See examples/policy/tags.rego for a deny example and the
# plan-JSON patterns (array membership on change.actions, null guard on
# change.after).
package main

import rego.v1

# Surface any resource that will be destroyed, so a destructive plan is obvious
# in review. actions is an array; a replace is ["delete","create"].
warn contains msg if {
	resource := input.resource_changes[_]
	"delete" in resource.change.actions
	msg := sprintf("%s will be destroyed", [resource.address])
}
