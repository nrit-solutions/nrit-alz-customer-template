# Azure landing zone live repository

This repository holds the Terragrunt configuration for an Azure landing zone
under `live/`. The tfpr PR-ops engine runs it from the public repository
`nrit-solutions/tfpr`. Plan and apply run from pull requests, and a daily job
reports drift.

The [bootstrap](https://docs.nrit.cloud/setup/bootstrap/) creates this repository. Do not create it with "Use this
template": a hand-made copy has no `live/customer.hcl`, no repository
variables and no `CODEOWNERS`, so onboarding fails.

## How changes are made

Open a branch and a pull request. The engine plans every impacted unit and
posts the plan on the pull request. After review, comment `tfpr apply` to
apply, and the merge gate turns green.

The bootstrap and the `live/_foundation/` units are platform-only. Workload
infrastructure goes into `live/` as units; see
[Add a workload unit](https://docs.nrit.cloud/scenarios/options/add-a-workload-unit/).
`mise.toml` pins the toolchain for local runs.

## License

`LICENSE` is Apache-2.0 and covers this repository's files. The engine and
`tfpr apply` have separate terms; see
[License](https://docs.nrit.cloud/reference/license/).

## Getting help

Ask the platform operator who set up this repository first. For engine
defects, see [Troubleshooting](https://docs.nrit.cloud/reference/troubleshooting/).

## Documentation

- [Repository anatomy](https://docs.nrit.cloud/anatomy/)
- [Plan and apply](https://docs.nrit.cloud/operations/plan-and-apply/)
- [Commands](https://docs.nrit.cloud/reference/commands/)
- [Policy, security, and cost gates](https://docs.nrit.cloud/operations/gates/)
- [Versions](https://docs.nrit.cloud/reference/versions/)
- [Scenarios](https://docs.nrit.cloud/scenarios/)
- [Onboarding checklist](ONBOARDING.md)
