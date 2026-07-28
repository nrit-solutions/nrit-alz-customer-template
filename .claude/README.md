# Agent tooling shipped with this repository

Three things support AI coding agents working in this repository. Each is
optional: nothing here runs in CI, and the repository works normally without any
of it.

| What | Where | Needs |
| --- | --- | --- |
| House rules | `AGENTS.md` and `CLAUDE.md` at the root | Nothing |
| Skills | `.claude/skills/` | Nothing, they are vendored files |
| MCP servers | `.mcp.json` at the root | Docker, for the Terraform server only |

## MCP servers

`.mcp.json` declares two servers. Your agent will ask before connecting to them
the first time.

**`microsoft-learn`** — Microsoft's official documentation server
([microsoftdocs/mcp](https://github.com/microsoftdocs/mcp)), reached over HTTPS at
`https://learn.microsoft.com/api/mcp`. It answers from current Microsoft Learn
content rather than the model's training data, which matters for Azure Policy,
CAF and WAF guidance, and resource naming rules. No account, no token, no local
install.

**`terraform`** — HashiCorp's official registry server
([hashicorp/terraform-mcp-server](https://github.com/hashicorp/terraform-mcp-server)),
run locally as a container, pinned to `1.1.0`. It looks up modules, providers,
and their inputs and outputs in the public Terraform Registry, which is how you
check an Azure Verified Module's arguments and current version without leaving
the editor.

It needs Docker running. Without Docker the server simply fails to start and the
rest of the repository is unaffected. The image is pulled on first use.

No token is set, because the public registry needs none. If you use HCP Terraform
or a private registry, add `TFE_ADDRESS` and `TFE_TOKEN` as `-e` arguments, and
keep the token in your own environment rather than committing it here.

## What leaves the repository

Both servers receive **queries**, not your Terraform code:

- `microsoft-learn` receives the documentation search terms your agent sends, and
  returns Microsoft Learn pages.
- `terraform` runs on your machine and queries the public Terraform Registry for
  module and provider metadata.

Neither is sent the contents of `live/`, your state, or your plan output. If your
organisation restricts outbound calls from developer machines, review both before
enabling, and delete `.mcp.json` if either is not acceptable.

## Turning it off

Delete `.mcp.json` to drop the servers, or `.claude/skills/` to drop the skills.
Both are inert files; removing them changes nothing about how the repository
plans or applies.
