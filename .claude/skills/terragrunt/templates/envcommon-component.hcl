# _envcommon/<component>.hcl — CLASSIC per-component shared config, imported by
# leaf terragrunt.hcl files via:
#   include "envcommon" {
#     path   = "${dirname(find_in_parent_folders("root.hcl"))}/_envcommon/vnet.hcl"
#     expose = true
#   }
#
# Requires an env.hcl ancestor (see below). In a tree without an env.hcl layer
# (modern trees fold environment into region.hcl) this errors on the first
# read. Kept for reviewing older repos built on the pattern.
#
# NOTE: the _envcommon pattern is "no longer recommended" by the docs but is
# fully supported and still common in the wild. Do not rewrite an existing repo
# off it unasked.

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env              = local.environment_vars.locals.environment

  # The module this component wraps — pinned per-leaf via ?ref= (not here).
  base_source_url = "github.com/your-org/infrastructure-catalog//modules/vnet"
}

# Inputs common to EVERY environment for this component. Leaves override the
# per-environment bits (sizes, counts, address spaces, …).
inputs = {
  name          = "vnet-${local.env}"
  address_space = ["10.0.0.0/16"] # default; leaves override
  tags          = { component = "vnet" }
}
