# Skills shipped with this repository

Agent skills, vendored so they work the moment the repository is created. No
installation step, no network access, and no dependency on any particular CLI.
Claude Code, and other agents that read repository-local skill directories, pick
them up automatically.

These are reference material for an agent, not code that runs. Nothing here is
executed by CI.

| Skill | Source | License | What it covers |
| --- | --- | --- | --- |
| `terragrunt` | NRIT Solutions | Proprietary, provided with this repository | Terragrunt 1.0: the CLI and its deprecations, HCL blocks, built-in functions, Stacks, best practices, an Azure/ALZ layer, and ready-to-copy templates for `root.hcl`, the hierarchy files, and a unit |
| `terraform-style-guide` | [hashicorp/agent-skills](https://github.com/hashicorp/agent-skills) | MPL-2.0, see `terraform-style-guide/LICENSE` | HashiCorp's official Terraform style conventions for writing and reviewing HCL |

## How these relate to AGENTS.md

`AGENTS.md` at the repository root states the house rules: the unit shape, the
naming convention, module pinning, the gates, and the change flow. It wins on
any conflict.

The skills are generic tooling knowledge. The terragrunt skill deliberately
documents more than one way to lay out a Terragrunt repository, and tells an
agent to read `AGENTS.md` before applying any default from it. If a skill and
`AGENTS.md` disagree about how this repository works, `AGENTS.md` is right.

## Updating

Both are copies. Nothing updates them automatically.

- `terragrunt` comes from the NRIT platform skills repository. Ask NRIT for the
  current version.
- `terraform-style-guide` comes from HashiCorp and can be refreshed with
  `npx skills add hashicorp/agent-skills --skill terraform-style-guide --copy`,
  keeping the `LICENSE` file alongside it.

## Adding more

The upstream sets carry skills for building Terraform providers, authoring
Azure Verified Modules, and Packer image building. They were left out because
this repository consumes published modules rather than authoring them. Add them
if that changes: `npx skills add hashicorp/agent-skills --list` shows what is
available.
