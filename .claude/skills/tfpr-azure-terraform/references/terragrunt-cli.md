# Terragrunt 1.0 CLI

Terragrunt 1.0 shipped on 2026-03-30. Its CLI redesign renamed most commands,
dropped the `--terragrunt-` flag prefix and moved environment variables from
`TERRAGRUNT_*` to `TG_*`. Much of what is written about Terragrunt predates
it. Canonical: <https://docs.terragrunt.com/reference/cli/> and
<https://docs.terragrunt.com/migrate/cli-redesign/>.

In a tfpr repository, plan and apply run in CI. Locally you format, discover,
validate offline and lock providers. `AGENTS.md`, under **Commands**, lists
what never runs from a shell.

## What changed

| Old form | 1.0 form |
| --- | --- |
| `apply-all`, `plan-all`, `destroy-all`, `output-all` | Removed. Use `run --all <command>` |
| `run-all <command>` | `run --all <command>`. `run-all` is a deprecated alias |
| `--terragrunt-working-dir`, `--terragrunt-non-interactive`, ... | `--working-dir`, `--non-interactive`: the prefix is gone |
| `TERRAGRUNT_*` variables | `TG_*`, for example `TERRAGRUNT_TFPATH` became `TG_TF_PATH` |
| A root file named `terragrunt.hcl` | `root.hcl`, found with `find_in_parent_folders("root.hcl")` |
| Top-level `skip = true` | The `exclude` block |
| Top-level `retryable_errors`, `retry_*` | The `errors { retry { ... } }` block |
| `graph`, `graph-dependencies` | `run --graph`, `dag graph` |
| `hclfmt`, `hclvalidate`, `validate-inputs` | `hcl fmt`, `hcl validate`, `hcl validate --inputs` |
| `--queue-include-dir`, `--queue-exclude-dir` and similar | `--filter`. The old flags remain as aliases |
| Unknown commands passed through to Terraform | Removed. Use `run -- <args>` |
| Automatic backend creation | Opt-in: `--backend-bootstrap` or `backend bootstrap` |
| `terragrunt-info`, `render-json` | `info print`, `render --format json` |

The default binary is `tofu`. This platform runs Terraform, so `root.hcl` sets
`terraform_binary = "terraform"`. Leave it set.

## The commands you use here

```sh
terragrunt hcl fmt                                      # format every .hcl file
terragrunt hcl fmt --check                              # fail on unformatted files
cd live && terragrunt find --json --dependencies --dag  # what discovery sees, in order
terragrunt --working-dir live/<unit> init -backend=false
TG_NO_AUTO_INIT=true terragrunt --working-dir live/<unit> validate
TG_NO_AUTO_INIT=true terragrunt --working-dir live/<unit> run -- providers lock -platform=darwin_arm64 -platform=linux_amd64
terragrunt --working-dir live/<unit> hcl validate --inputs
terragrunt --working-dir live/<unit> render --format json
```

`render` shows a unit's resolved configuration with every include merged. It
is the fastest way to see which layer file a value came from.

## Running Terraform through Terragrunt

- `terragrunt run <command>` wraps Terraform. `plan`, `init`, `validate` and
  `output` also work as shortcuts.
- `terragrunt run -- <args>` passes everything after `--` to Terraform
  verbatim: `run -- providers lock ...`, `run -- state list`.
- `terragrunt run --all <command>` runs across every unit in dependency order.
  `apply` and `destroy` under `--all` add `-auto-approve` unless you pass
  `--no-auto-approve`, and `destroy` runs in reverse order.
- `terragrunt exec -- <command>` runs any command in the unit's prepared
  working directory.

## Discovery

- `terragrunt find` lists units and stacks. `--dag` sorts them by dependency,
  `--json` makes the output machine-readable, `--dependencies` includes each
  unit's dependencies.
- `terragrunt list` enumerates units.
- `terragrunt dag graph` prints the dependency graph.

The engine discovers units through `projects.yml`, not through these commands,
but both walk the same tree: a folder that `find` does not list is a folder
the engine will not plan.

## Common flags

| Flag | Purpose |
| --- | --- |
| `--working-dir <dir>` | Run as if from `<dir>` |
| `--all` | With `run`, every unit |
| `--graph` | With `run`, the graph around the current unit |
| `--non-interactive` | Never prompt |
| `--no-auto-init` | Do not initialize automatically |
| `--no-auto-approve` | Keep the approval prompt under `--all` |
| `--parallelism <n>` | Cap concurrent units |
| `--filter <expr>` | Select units, see below |
| `--filter-affected` | Shorthand for units changed since the default branch |
| `--inputs-debug` | Write the resolved inputs to `terragrunt-debug.tfvars.json` |
| `--tf-path <bin>` | The Terraform binary |

## The --filter query language

- Glob: `--filter 'landingzones/**'`
- Attribute: `--filter 'type=unit'`, `--filter 'reading=customer.hcl'`
- Negation: `--filter '!_foundation/**'`
- Intersection: `--filter 'landingzones/** | type=unit'`
- Git range: `--filter '[main...HEAD]'`
- Graph: `network...` for a unit and its dependents, `...network` for a unit
  and its dependencies

`reading=` answers "which units read this file", which is how you scope the
impact of an edit to a layer file.

## Environment variables

| Variable | Was | Purpose |
| --- | --- | --- |
| `TG_NO_AUTO_INIT` | `TERRAGRUNT_AUTO_INIT=false` | No automatic init. Needed for the offline validate |
| `TG_TF_PATH` | `TERRAGRUNT_TFPATH` | The Terraform binary |
| `TG_NON_INTERACTIVE` | `TERRAGRUNT_NON_INTERACTIVE` | Never prompt |
| `TG_PARALLELISM` | `TERRAGRUNT_PARALLELISM` | Run queue concurrency |
| `TG_PROVIDER_CACHE` | | The provider cache server |
| `TG_EXPERIMENT` | | Named experiments |
| `TG_STRICT_CONTROL` | | Turn deprecations into errors |

## Strict controls

`--strict-control <name>` or `TG_STRICT_CONTROL=<name>` makes a deprecated
behavior an error ahead of its removal. Useful ones: `deprecated-commands`,
`cli-redesign`, `root-terragrunt-hcl`. See
<https://docs.terragrunt.com/reference/strict-controls/>.

## Auto-init and retries

- Auto-init is on. It re-initializes when sources or modules change, and can
  miss a provider constraint change, which shows as "Required plugins are not
  installed". Run `init` again, with `-backend=false` locally.
- Retries are off unless an `errors { retry { ... } }` block sets them. See
  [config-blocks.md](config-blocks.md#errors).
- Never set `TF_PLUGIN_CACHE_DIR` for a `run --all`. Concurrent writes corrupt
  the cache. Use `TG_PROVIDER_CACHE` instead.
