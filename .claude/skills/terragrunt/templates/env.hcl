# env.hcl — LEGACY per-environment vars. Only for an older classic layout with a
# distinct <account|subscription>/<region>/<env>/ level. Modern trees do NOT use
# this: environment lives in region.hcl (see region.hcl), and the Stacks layout
# folds environment into folder/stack naming. Prefer those. Kept here only for
# reviewing/maintaining existing repos on the old pattern.
# Read via read_terragrunt_config(find_in_parent_folders("env.hcl")).

locals {
  environment = "prod" # qa | stage | prod
}
