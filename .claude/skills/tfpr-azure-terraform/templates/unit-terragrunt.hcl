# <unit>: <what this unit owns, in one line>.
# Providers: the root default set (azurerm, azapi, azuread).
# Own state because <why it plans and applies apart from its neighbours>.

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

# Ordering only: these apply first. Values cross by naming convention, not outputs.
dependencies {
  paths = ["../<unit-that-must-exist-first>"]
}
