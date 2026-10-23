# Terragrunt functions

Terragrunt adds these to the Terraform built-in functions. This page lists
the ones the platform shape uses. The full list is at
<https://docs.terragrunt.com/reference/hcl/functions/>.

## Finding files in the tree

| Function | Returns | Used for |
| --- | --- | --- |
| `find_in_parent_folders(name, [fallback])` | The path of the nearest `name` above the current folder | Every include and every layer file read. Always pass the name: the bare form looks for `terragrunt.hcl` and is legacy |
| `path_relative_to_include()` | The path from the included file's folder to the current unit | The state key |
| `get_terragrunt_dir()` | The current config file's folder | A vendored `lib/` path in a provider block |
| `get_repo_root()` | The repository root | Paths that must not depend on depth |
| `get_path_from_repo_root()` | The current folder relative to the repository root | Labels and messages |

The second argument to `find_in_parent_folders` is returned when nothing is
found. `root.hcl` uses it with `read_terragrunt_config`'s own default to make
`customer.hcl` optional:

```hcl
customer_vars = read_terragrunt_config(find_in_parent_folders("customer.hcl", "customer.hcl"), {
  locals = { tenant_root_id = "00000000-0000-0000-0000-000000000000" }
})
```

Every other layer file is read without a fallback, on purpose: a missing
`region.hcl` should fail, not deploy to a default region.

## Reading configuration

| Function | Returns |
| --- | --- |
| `read_terragrunt_config(path, [default])` | Another config parsed as an object. Read its values as `.locals.<name>` |
| `get_env(name, [default])` | An environment variable, or the default |

`get_env` with a placeholder default is how `root.hcl`, `tenant.hcl` and the
foundation's `subscription.hcl` stay valid offline. The real values arrive
from the Action variables the reusable workflows export.

## Generating content

Terraform's own `jsonencode` does the work in `generate "context"`: it turns
each Terragrunt local into a valid Terraform literal, quoting strings and
escaping where needed. Use it for any value interpolated into generated
Terraform.

## Selecting units

| Function | Does |
| --- | --- |
| `mark_as_read(path)` | Marks a file as read, so `--filter 'reading=<file>'` finds the units that depend on it |
| `mark_glob_as_read(pattern)` | The same for a glob |

`read_terragrunt_config` marks its file as read already.

## Less common

| Function | Returns |
| --- | --- |
| `get_default_retryable_errors()` | The built-in retryable error patterns, for an `errors` block |
| `get_terraform_command()` | The Terraform command being run |
| `get_platform()` | `darwin`, `linux` or `windows` |
| `run_cmd(cmd, args...)` | A shell command's output. Avoid: it runs on every parse, in CI too |

There are no Azure helper functions. Tenant and subscription ids come from the
layer files and `get_env`.

Secrets never pass through a Terragrunt function. They stay in Key Vault and
are read ephemerally in `main.tf`, as in [sharing-values.md](sharing-values.md).
