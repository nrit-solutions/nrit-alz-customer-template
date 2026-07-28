# terragrunt.stack.hcl — Stacks leaf. Composes units that are GENERATED into
# ./.terragrunt-stack/ (git-ignore that dir).
#
# DISCOVERY TRAP: a stack leaf has no terragrunt.hcl. CI that discovers units
# by walking for terragrunt.hcl (comment-ops engines, Atlantis-style setups)
# walks straight past it: the PR reports zero impacted projects, gates pass with
# nothing to gate, and the PR can merge green having deployed nothing. No error
# appears anywhere. Confirm the repo's pipeline understands Stacks (and check
# its AGENTS.md) before adding one.
#
# One per deployable group, e.g.
#   landingzones/corp-prod/westeurope/platform/terragrunt.stack.hcl
#
# Commands:  terragrunt stack generate   (render, inspect)
#            terragrunt stack run plan|apply
#            terragrunt stack output
#            terragrunt stack clean

locals {
  name    = "corp-prod"
  version = "v1.4.0" # catalog ref pinned per environment for atomic promote/rollback
}

unit "resource_group" {
  source = "github.com/your-org/infrastructure-catalog//units/resource-group?ref=${local.version}"
  path   = "resource-group"
  values = {
    version = local.version
    name    = "rg-${local.name}"
  }
}

unit "vnet" {
  source = "github.com/your-org/infrastructure-catalog//units/vnet?ref=${local.version}"
  path   = "vnet"
  values = {
    version       = local.version
    name          = "vnet-${local.name}"
    address_space = ["10.10.0.0/16"]
    rg_path       = "../resource-group" # relative dependency wiring (consumed inside the unit)
  }
}

unit "key_vault" {
  source = "github.com/your-org/infrastructure-catalog//units/key-vault?ref=${local.version}"
  path   = "key-vault"
  values = {
    version   = local.version
    name      = "kv-${local.name}"
    rg_path   = "../resource-group"
    vnet_path = "../vnet"
  }
}

# Nest another stack for reuse / multi-env fan-out (parent values propagate down):
# stack "monitoring" {
#   source = "github.com/your-org/infrastructure-catalog//stacks/monitoring?ref=${local.version}"
#   path   = "monitoring"
#   values = { environment = "prod" }
# }
