# env.hcl
#
# Environment of the connectivity subscription. Platform subscriptions are
# always prod: there is one hub, and it carries traffic for every environment.

locals {
  environment = "prod"
}
