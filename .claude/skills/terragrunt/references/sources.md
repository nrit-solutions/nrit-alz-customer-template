# Authoritative Terragrunt sources

Prefer the official docs; verify version-sensitive claims there before answering.
The docs moved to **`docs.terragrunt.com`** (old `terragrunt.gruntwork.io`
308-redirects there).

## Official docs (canonical)
- Quick start — https://docs.terragrunt.com/getting-started/quick-start/
- Terminology — https://docs.terragrunt.com/getting-started/terminology/
- Units — https://docs.terragrunt.com/features/units/
- State backend — https://docs.terragrunt.com/features/units/state-backend/
- Stacks — https://docs.terragrunt.com/features/stacks/
- Run Queue — https://docs.terragrunt.com/features/run-queue/
- Auto-init — https://docs.terragrunt.com/features/units/auto-init/
- Auto-retry — https://docs.terragrunt.com/features/auto-retry/
- Catalog — https://docs.terragrunt.com/features/catalog/
- **HCL blocks** — https://docs.terragrunt.com/reference/hcl/blocks/
- **HCL functions** — https://docs.terragrunt.com/reference/hcl/functions/
- **CLI reference** — https://docs.terragrunt.com/reference/cli/
- Strict controls — https://docs.terragrunt.com/reference/strict-controls/

## Migration pages (these correct most stale knowledge)
- **CLI redesign** — https://docs.terragrunt.com/migrate/cli-redesign/
  (run --all, dropped `--terragrunt-` prefix, `TG_*` env vars)
- **Migrating to Stacks / from `_envcommon`** — https://docs.terragrunt.com/migrate/terragrunt-stacks/
- **Root `terragrunt.hcl` → `root.hcl`** — https://docs.terragrunt.com/migrate/migrating-from-root-terragrunt-hcl/

## Example repos
Upstream Gruntwork examples. All use the catalog + `?ref=` shape; a repo built
on plain-TF units looks different, so check the repo's own conventions before
copying a shape from these.
- Catalog (modern reusable) — https://github.com/gruntwork-io/terragrunt-infrastructure-catalog-example
- Live + Stacks (modern live) — https://github.com/gruntwork-io/terragrunt-infrastructure-live-stacks-example
- Live (classic, pre-Stacks; most common in the wild) — https://github.com/gruntwork-io/terragrunt-infrastructure-live-example
- Modules (classic reusable; ARCHIVED) — https://github.com/gruntwork-io/terragrunt-infrastructure-modules-example

## Blog / background
- Terragrunt 1.0 released (2026-03-30) — https://www.gruntwork.io/blog/terragrunt-1-0-released
- The road to 1.0: Stacks — https://www.gruntwork.io/blog/the-road-to-terragrunt-1-0-stacks
- Keep your Terraform code DRY (foundational rationale) — https://www.gruntwork.io/blog/terragrunt-how-to-keep-your-terraform-code-dry-and-maintainable
- Managing secrets in Terraform — https://www.gruntwork.io/blog/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code

## CI/CD
- Official GitHub Action — https://github.com/gruntwork-io/terragrunt-action
- Gruntwork Pipelines — https://www.gruntwork.io/platform/pipelines

## Source / repo
- Terragrunt — https://github.com/gruntwork-io/terragrunt

## Azure
- azurerm backend (HashiCorp) — https://developer.hashicorp.com/terraform/language/backend/azurerm
- Store TF state in Azure Storage (MS Learn) — https://learn.microsoft.com/azure/developer/terraform/store-state-in-azure-storage
- Azure Verified Modules — https://azure.github.io/Azure-Verified-Modules/

## Live-doc lookups
- Microsoft Learn MCP (`microsoft_docs_search` / `microsoft_docs_fetch`) for
  current azurerm provider / Azure auth specifics.
- context7 MCP (`resolve-library-id` → `query-docs`) for current Terragrunt or
  azurerm provider docs.
