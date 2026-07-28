# Terragrunt CLI reference (1.0)

The 1.0 CLI redesign (RFC #3445) reorganized commands and **removed the
`--terragrunt-` flag prefix**. Env vars moved from `TERRAGRUNT_*` to `TG_*`.
Source of truth: `docs.terragrunt.com/reference/cli/` and `/migrate/cli-redesign/`.

## Command groups

### Running OpenTofu/Terraform
- `terragrunt run <cmd>` — explicit wrapper around tofu/terraform.
  - `terragrunt run --all <cmd>` — run across every discovered unit in DAG order
    (replaces `run-all`, `apply-all`, `plan-all`, …).
  - `terragrunt run --graph <cmd>` — run the dependency graph *around the current
    unit* (replaces `terragrunt graph`).
  - `terragrunt run -- <args>` — everything after `--` goes verbatim to
    tofu/terraform: `terragrunt run -- plan -no-color`,
    `terragrunt run -- workspace list`.
- **Shortcuts** still work for common commands: `terragrunt plan`,
  `terragrunt apply`, `terragrunt destroy`, `terragrunt output`, `terragrunt init`
  are shortcuts for `terragrunt run <cmd>`.
- **No implicit passthrough** (since v0.88): unknown subcommands are NOT forwarded
  to tofu. Use `terragrunt run -- <cmd>`.
- `terragrunt exec -- <command>` — run an arbitrary command in the unit's prepared
  working dir (with TF_VAR_* etc. set).

### Stacks
- `terragrunt stack generate` — render `terragrunt.stack.hcl` into `.terragrunt-stack/`.
- `terragrunt stack run <cmd>` — generate then run across all generated units.
- `terragrunt stack output [name]` — read outputs from the stack.
- `terragrunt stack clean` — delete generated `.terragrunt-stack/` directories.

### Discovery / DAG
- `terragrunt find` — recursively discover units & stacks. Flags: `--dag` (sort
  by dependency order), `--json`, `--dependencies`, `--external`. Serves the job
  `output-module-groups` used to do, though the docs do not state it as a formal
  replacement.
- `terragrunt list` — enumerate units/stacks.
- `terragrunt dag graph` — emit the dependency graph (replaces `graph-dependencies`).

### HCL tooling
- `terragrunt hcl fmt` — format `.hcl` (replaces `hclfmt`).
- `terragrunt hcl validate` — validate HCL (replaces `hclvalidate`).
- `terragrunt hcl validate --inputs` — check that unit inputs match module
  variables (replaces `validate-inputs`).

### Catalog / scaffolding
- `terragrunt catalog [repo-url]` — TUI to browse modules from `catalog { urls }`;
  press `S` to scaffold a unit. ⚠️ Boilerplate templates can run shell/hooks —
  use `no_shell`/`no_hooks` (or CLI flags) for untrusted templates.
- `terragrunt scaffold <module-url>` — generate a `terragrunt.hcl` for a module.

### State backend
- `terragrunt backend bootstrap` — create the backend resources (opt-in; replaces
  the old automatic bootstrap). Also `--backend-bootstrap` / `TG_BACKEND_BOOTSTRAP`.
- `terragrunt backend migrate <src> <dst>` — move state.
- `terragrunt backend delete` — remove backend resources.

### Info / render
- `terragrunt info print` — print resolved config info (replaces `terragrunt-info`).
- `terragrunt render --format json -w` — render resolved config as JSON
  (replaces `render-json`).

## Common flags (no more `--terragrunt-` prefix)

| Flag | Purpose |
|---|---|
| `--all` | run across all units (with `run`) |
| `--graph` | run the DAG around the current unit |
| `--non-interactive` | never prompt (was `--terragrunt-non-interactive`) |
| `--working-dir <dir>` | working directory |
| `--parallelism <n>` | cap concurrent units in the run queue |
| `--no-auto-init` | disable auto-init |
| `--no-auto-approve` | require approval on `run --all apply/destroy` (they auto-add `-auto-approve` otherwise) |
| `--tf-path <bin>` | path to tofu/terraform binary |
| `--backend-bootstrap` | provision backend resources before running (documented under backend bootstrap, not on the `run` page; no effect for azurerm, which is still experimental) |
| `--queue-ignore-errors` | run-queue failure behavior |
| `--filter <expr>` | select which units to operate on (see below) |
| `--filter-affected` | shorthand for `--filter '[main...HEAD]'` |
| `--inputs-debug` | write debug `terragrunt-debug.tfvars.json` (was `--terragrunt-debug`) |

## The `--filter` query language (1.0)

Consolidates the seven old `--queue-include-dir`/`--queue-exclude-dir`/… flags
(kept as aliases that expand to `--filter`).

- Glob: `--filter 'prod/**'`
- Attribute match: `--filter 'type=unit'`, `external=false`, `reading=shared.hcl`
- Negation: `--filter '!experimental/**'`
- Intersection: `--filter 'prod/** | type=unit'`
- Git diff (changed since): `--filter '[main...HEAD]'`
- Graph traversal: `service...` (unit + its dependents), `...vpc` (unit + its
  dependencies)

Typical CI usage — plan only what a PR changed, plus dependents:
```bash
terragrunt run --all --filter '[main...HEAD]...' -- plan
```

## Key environment variables (`TG_*`)

| Env var | Was | Purpose |
|---|---|---|
| `TG_TF_PATH` | `TERRAGRUNT_TFPATH` | tofu/terraform binary |
| `TG_NON_INTERACTIVE` | `TERRAGRUNT_NON_INTERACTIVE` | never prompt |
| `TG_BACKEND_BOOTSTRAP` | — | provision backend resources |
| `TG_NO_AUTO_INIT` | `TERRAGRUNT_AUTO_INIT=false` | disable auto-init |
| `TG_PARALLELISM` | `TERRAGRUNT_PARALLELISM` | run-queue concurrency |
| `TG_EXPERIMENT` | — | enable named experiments (e.g. `azure-backend`) |
| `TG_PROVIDER_CACHE` | — | enable the Provider Cache Server |

## Strict Controls

Opt into breaking/removed behavior early or turn warnings into errors:
`--strict-control <name>` or `TG_STRICT_CONTROL=<name>`. Notable controls:
`root-terragrunt-hcl` (forbid root file named `terragrunt.hcl`),
`cli-redesign`, `deprecated-commands`. See `/reference/strict-controls/`.

## Auto-init / auto-retry notes

- **Auto-init** is on by default; Terragrunt re-inits when source/state/modules
  change. It can miss cases (e.g. bumping `required_providers` in a cached
  module → "Required plugins are not installed") — fix with `terragrunt init` or
  clear `.terragrunt-cache`.
- **Auto-retry is NOT on by default.** Configure it with an `errors { retry { … } }`
  block (see `config-blocks.md`). The old top-level `retryable_errors` is removed.
