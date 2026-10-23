# Other shapes you may meet

Public Terragrunt examples mostly use shapes this platform does not. Recognize
them, and do not bring them into a tfpr live repository.

## Catalog repository with ?ref= sources

Reusable modules or units live in a separate, SemVer-tagged catalog
repository. Each live unit points at one:

```hcl
terraform {
  source = "git::https://github.com/<org>/<catalog>.git//modules/vnet?ref=v1.4.0"
}
```

Code is promoted between environments by bumping the ref. Here, a unit's code
is the `main.tf` beside it, calling public registry modules at an exact
`version`. There is no catalog and no git source.

## Terragrunt Stacks

A `terragrunt.stack.hcl` holds `unit` and `stack` blocks that generate units
into `.terragrunt-stack/` at run time, with `values` passed into each.
`terragrunt stack generate` renders them and `terragrunt stack run` runs them.
Stacks have been GA since v0.78.0 and suit fanning one pattern across many
environments.

A stack leaf has no `terragrunt.hcl`, so tfpr discovery skips it. A PR adding
one plans nothing, passes every gate with nothing to gate, and merges green
having deployed nothing. The repository invariants hook fails on any
`terragrunt.stack.hcl` under `live/` for that reason.

## _envcommon and multiple includes

An older pattern: shared per-component config in `_envcommon/<component>.hcl`,
pulled into each leaf with a second labeled include. The Terragrunt docs no
longer recommend it. Here, sharing happens through `root.hcl`, the layer
files and `local.context`.

## A root file named terragrunt.hcl

Before 1.0 the root config was often `terragrunt.hcl` at the top of the tree,
found with a bare `find_in_parent_folders()`. The current name is `root.hcl`,
passed by name.

## SOPS-encrypted secret files

`sops_decrypt_file` keeps a committed secret out of git, not out of state.
Here, secrets stay in Key Vault and are read ephemerally.

## When you meet one

Review such a repository by its own conventions. Migrating between shapes is
a project, never a side effect of another change.

- [Stacks](https://docs.terragrunt.com/features/stacks/)
- [Migrating from _envcommon to Stacks](https://docs.terragrunt.com/migrate/terragrunt-stacks/)
- [Migrating from a root terragrunt.hcl](https://docs.terragrunt.com/migrate/migrating-from-root-terragrunt-hcl/)
