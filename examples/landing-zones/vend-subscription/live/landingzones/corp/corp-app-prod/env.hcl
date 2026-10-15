# env.hcl
#
# Environment of this landing zone. One landing zone belongs to exactly one
# environment; the value feeds names and the env tag.

locals {
  environment = "prod"
}
