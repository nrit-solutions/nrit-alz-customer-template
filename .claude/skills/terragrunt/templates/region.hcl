# region.hcl — per-region vars. Place at each <subscription>/<region>/ folder,
# and co-locate one in each <subscription>/_global/ folder too: root.hcl reads
# region.hcl unconditionally, and a region-agnostic (_global) deployable has no
# region-folder ancestor to inherit from, so it needs its own (nominal) copy.
# Read by root.hcl via read_terragrunt_config(find_in_parent_folders("region.hcl")).

locals {
  location       = "westeurope" # Azure region (AWS: aws_region = "eu-west-1")
  location_short = "weu"        # short form used in resource names

  # environment lives here, not in a separate env.hcl layer. Exposed by root.hcl
  # and used in tags/naming.
  environment = "prod" # qa | stage | prod
}
