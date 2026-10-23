# Skills shipped with this repository

Agent skills, vendored so they work the moment the repository exists. No
installation step, no network access, and no dependency on any particular CLI.
Claude Code, and other agents that read repository-local skill directories, pick
them up automatically.

These are reference material for an agent, not code that runs. Nothing here is
executed by CI.

| Skill | Source | License | What it covers |
| --- | --- | --- | --- |
| `tfpr-azure-terraform` | Platform operator | Apache-2.0, see `LICENSE` at the repository root | Authoring and reviewing units in this repository: the unit contract, the hierarchy files and root contract, sharing values between units, Azure specifics, Terraform style, the Terragrunt 1.0 CLI, a review checklist, and ready-to-copy templates |

## How this relates to AGENTS.md

`AGENTS.md` at the repository root states the house rules: the unit shape, the
naming convention, module pinning, the gates, and the change flow. It wins on
any conflict. The skill is the how-to and the reference behind those rules, and
it tells an agent to read `AGENTS.md` first.

## Updating

The skill is a copy and nothing updates it automatically. It comes from the
platform operator's skills repository together with `AGENTS.md`; ask the
platform operator for the current version and take both in one change.
