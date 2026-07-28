# Terragrunt built-in HCL functions

Terragrunt adds these on top of all native OpenTofu/Terraform functions.
Canonical: `docs.terragrunt.com/reference/hcl/functions/`.

## Path / hierarchy navigation (the most-used ones)

| Function | Returns |
|---|---|
| `find_in_parent_folders(name, [fallback])` | Absolute path to the first `name` found walking up the tree. **Call as `find_in_parent_folders("root.hcl")`** — the no-arg form looks for `terragrunt.hcl` and is legacy. |
| `path_relative_to_include([name])` | Path from the included (parent) config's dir down to this config. Use for the state `key` so each unit is unique. |
| `path_relative_from_include([name])` | Inverse: path from the parent back up to the current dir. Useful for relative `source`. |
| `get_terragrunt_dir()` | Dir of the current config file. |
| `get_parent_terragrunt_dir([name])` | Absolute dir of the root parent config. |
| `get_original_terragrunt_dir()` | Dir of the original config being read (before includes). |
| `get_working_dir()` | Absolute dir where tofu/terraform actually runs. |
| `get_repo_root()` | Absolute git repo root (errors if not a git repo). |
| `get_path_from_repo_root()` | Path from repo root to current dir. |
| `get_path_to_repo_root()` | Relative path back up to repo root. |

Idiomatic state key:
```hcl
key = "${path_relative_to_include()}/terraform.tfstate"
```

## Reading config & vars

| Function | Returns |
|---|---|
| `read_terragrunt_config(path, [default])` | Parse another Terragrunt config into an object. Read it as `.locals.x`, `.inputs.x`, etc. |
| `read_tfvars_file(path)` | Read a `.tfvars`/`.tfvars.json` into a map. |
| `get_env(NAME, [DEFAULT])` | Env var, with optional default. |

```hcl
locals {
  subscription_vars = read_terragrunt_config(find_in_parent_folders("subscription.hcl"))
  subscription_id   = local.subscription_vars.locals.subscription_id
}
```

## Secrets

| Function | Returns |
|---|---|
| `sops_decrypt_file(path)` | Decrypt a SOPS-encrypted YAML/JSON/INI/ENV/raw file. Pair with `yamldecode`. |

```hcl
locals {
  secrets = yamldecode(sops_decrypt_file("${get_terragrunt_dir()}/secrets.enc.yaml"))
}
inputs = { admin_password = local.secrets.admin_password }
```

## Running commands / CI helpers

| Function | Returns |
|---|---|
| `run_cmd(cmd, args...)` | Run a shell command, return stdout. Supports `--terragrunt-quiet`, `--terragrunt-global-cache`, `--terragrunt-no-cache`. Prefer native functions / data sources where possible. |
| `mark_as_read(path)` / `mark_glob_as_read(pattern)` | Mark files so `--filter 'reading=…'` / `--queue-include-units-reading` can target units that read them. |
| `get_platform()` | `darwin` / `linux` / `windows` / `freebsd`. |

## Command introspection (for `extra_arguments`)

`get_terraform_command()`, `get_terraform_cli_args()`,
`get_terraform_commands_that_need_vars()`, `…_need_input()`,
`…_need_locking()`, `…_need_parallelism()`.

## Misc

| Function | Returns |
|---|---|
| `get_default_retryable_errors()` | The built-in list of retryable error regexes (seed your `errors { retry { … } }`). |
| `constraint_check(version, constraint)` | Boolean version-constraint check. |
| `deep_merge(maps...)` | Deep-merge maps (experiment-gated in some versions). |

## AWS-only helpers (for completeness; not used on Azure)

`get_aws_account_id()`, `get_aws_account_alias()`,
`get_aws_caller_identity_arn()`, `get_aws_caller_identity_user_id()`.

> Azure note: there is no `get_azure_*` equivalent. Pull subscription/tenant IDs
> from `subscription.hcl` via `read_terragrunt_config`, or from `ARM_*` env vars
> via `get_env`.
