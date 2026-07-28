# Terragrunt HCL blocks reference

Canonical: `docs.terragrunt.com/reference/hcl/blocks/`. These appear in
`terragrunt.hcl` and `root.hcl` (and a subset in `terragrunt.stack.hcl`).

## `include` — inherit a parent config

The backbone of the classic DRY pattern. A unit includes `root.hcl`.

```hcl
include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true            # makes include.root.locals.* readable in this file
  # merge_strategy = "deep"  # no_merge | shallow (default) | deep
}
```
- Multiple labeled includes allowed (e.g. `include "root"` + `include "envcommon"`).
- `merge_strategy` accepts `no_merge`, `shallow`, `deep`. **The default is
  `shallow`**, not `no_merge`. Use `deep` to deep-merge maps like `inputs`.
- **Overriding an inherited `generate` block needs `merge_strategy = "deep"`.**
  The docs say `generate` and `remote_state` are not deep-mergeable, so a child
  block should simply replace the parent's under any strategy. That is not what
  happens. On Terragrunt 1.0.7, a unit that declares a `generate "provider"`
  while inheriting one from `root.hcl` under the default shallow merge aborts:

  ```
  ERROR  Detected generate blocks with the same name: [provider]
  ```

  No files are generated and the run stops. Adding `merge_strategy = "deep"` to
  the include makes the override work. Keep the attribute; do not "clean it up"
  on the strength of the docs page.
- **Not supported inside `terragrunt.stack.hcl`.**

## `dependency` — read another unit's outputs

```hcl
dependency "vnet" {
  config_path = "../vnet"

  mock_outputs = {
    vnet_id      = "00000000-mock"
    subnet_ids   = { app = "mock-subnet" }
  }
  # CRITICAL safety: never let mocks reach apply
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  # mock_outputs_merge_strategy_with_state = "shallow"  # no_merge | shallow | deep_map_only
  # skip_outputs = true   # always use mocks if set; don't combine carelessly with mock_outputs
}

inputs = {
  vnet_id = dependency.vnet.outputs.vnet_id
}
```
- `mock_outputs` are used only when real outputs are unavailable (dependency not
  yet applied). `skip_outputs = true` means *always* skip calling `output`.
- Always set `mock_outputs_allowed_terraform_commands = ["validate", "plan"]` —
  otherwise mock values can silently be applied.

## `dependencies` — ordering only (no outputs)

```hcl
dependencies {
  paths = ["../vnet", "../key-vault"]
}
```
Use when you need `run --all` ordering but don't consume outputs.

## `generate` — write a file into the working dir before tofu runs

```hcl
generate "provider" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"   # overwrite | overwrite_terragrunt | skip | error
  # disable = false
  contents  = <<EOF
provider "azurerm" {
  features {}
}
EOF
}
```
`overwrite_terragrunt` only overwrites files Terragrunt itself generated (safe).

**Overriding a `generate` block inherited from `root.hcl`.** A unit can do it,
but only if its `include` sets `merge_strategy = "deep"`. Without it, two
same-named generate blocks are a hard error and nothing is generated:

```
ERROR  Detected generate blocks with the same name: [provider]
```

Keep the root `generate "provider"` block. Units needing a different provider
set (e.g. one swapping in the `alz` provider) override it with a deep-merged
include. Do not solve this by deleting the root block: every unit that declares
no provider of its own depends on it, and they are usually the majority.

## `remote_state` — backend config (+ optional bootstrap)

```hcl
remote_state {
  backend  = "azurerm"            # azurerm | s3 | gcs | …
  generate = { path = "backend.tf", if_exists = "overwrite_terragrunt" }
  config = {
    resource_group_name  = local.subscription_vars.locals.tfstate_rg
    storage_account_name = local.subscription_vars.locals.tfstate_sa
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    subscription_id      = local.subscription_vars.locals.subscription_id
    use_azuread_auth     = true
  }
  # disable_init = false
  # encryption = { … }   # state encryption (S3 native, etc.)
}
```
- `key = "${path_relative_to_include()}/terraform.tfstate"` gives every unit a
  unique state path automatically.
- Do **not** also use a `generate "backend"` block for the same backend — pick one.
- In 1.0, backend resource creation is opt-in (`--backend-bootstrap` /
  `terragrunt backend bootstrap`). azurerm auto-provisioning is experimental;
  pre-create the SA/container (see `azure.md`).

## `terraform` — control the tofu/terraform invocation

```hcl
terraform {
  source = "git::git@github.com:org/catalog.git//modules/vnet?ref=v1.4.0"

  extra_arguments "common_vars" {
    commands  = ["plan", "apply"]
    arguments = ["-compact-warnings"]
  }

  before_hook "fmt_check" {
    commands     = ["plan", "apply"]
    execute      = ["tofu", "fmt", "-check"]
    run_on_error = false
  }
  after_hook "notify" {
    commands = ["apply"]
    execute  = ["echo", "applied"]
  }
  error_hook "explain_lock" {
    commands  = ["apply"]
    on_errors = [".*state blob is already locked.*"]
    execute   = ["echo", "Another run holds the state lock"]
  }
}
```

## `inputs` — variables passed to the module

```hcl
inputs = {
  name     = "app-prod"
  location = local.region_vars.locals.location
}
```
Passed to tofu as `TF_VAR_*`. Replaces `*.tfvars`.

## `locals` — local values

```hcl
locals {
  subscription_vars = read_terragrunt_config(find_in_parent_folders("subscription.hcl"))
  region_vars       = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env               = local.region_vars.locals.location
}
```

## `errors` — retry & ignore

```hcl
errors {
  retry "transient_azure" {
    retryable_errors   = [".*RetryableError.*", ".*timeout.*", ".*TooManyRequests.*"]
    max_attempts       = 3
    sleep_interval_sec = 10
  }
  ignore "known_benign" {
    ignorable_errors = [".*specific benign error.*"]
    message          = "Ignored a known-benign error"
    signals          = { alert = false }
  }
}
```
Replaces the removed top-level `retryable_errors`/`retry_*` attributes.

## `exclude` — dynamically skip a unit

```hcl
exclude {
  if                  = local.region_vars.locals.location == "westus"
  actions             = ["plan", "apply"]   # or ["all"]
  exclude_dependencies = false
  no_run              = false
}
```
Replaces the removed top-level `skip = true`.

## `feature` — runtime feature flags

```hcl
feature "enable_diagnostics" { default = false }   # override: --feature enable_diagnostics=true

inputs = {
  diagnostics_enabled = feature.enable_diagnostics.value
}
```

## `catalog` — module sources for the catalog TUI

```hcl
catalog {
  urls = [
    "https://github.com/org/infrastructure-catalog",
  ]
  # default_template = "…"
  # no_shell = true   # security: block template shell execution
  # no_hooks = true
}
```

## `engine` — experimental IaC engine plugin

```hcl
engine {
  source  = "github.com/gruntwork-io/terragrunt-engine-opentofu"
  version = "v0.0.x"
  type    = "rpc"
}
```
Experimental — requires `TG_EXPERIMENT=engine` (formerly `TG_EXPERIMENTAL_ENGINE=1`).
Not for production.

## `unit` / `stack` — only inside `terragrunt.stack.hcl`

See `stacks.md`.
