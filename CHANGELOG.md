# Changelog

Changes to this repository: version bumps (AVM modules, the ALZ and AMBA
library refs, the engine caller pins), new units, and new workloads.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- Renovate now tracks the Terraform registry modules in `live/`: every module
  bump arrives in one grouped pull request. A provider version outside its
  range in `root.hcl` or a unit override is listed on the dependency dashboard,
  with no pull request until it is approved there. Renovate only scans `live/`
  and `.github/`, so `examples/` is not tracked. Lock files stay manual.

### Changed

- tfpr v12.5.2 to v12.5.3 in all five callers: runtime downloads retry for
  two minutes and GitHub reads for about a minute, so a short GitHub 5xx no
  longer stops a run or leaves its check rows in progress.
- tfpr v12.5.0 to v12.5.2 in all five callers. v12.5.1 refuses an apply whose
  only approval a ruleset dismissed after a later push, names the forget action
  in the check row, and no longer fails a run when another run already released
  a lock; v12.5.2 makes a `tfpr unlock` comment release the locks again.
- tfpr v12.4.0 to v12.5.0 in all five callers. v12.4.1 stops a deleted shared
  `.hcl` that no unit reads from blocking a folder move; v12.5.0 warns when a
  caller drifts from the canonical example.
- tfpr v12.3.1 to v12.4.0 in all five callers: a pull request that deletes a
  unit folder plans the unit's destroy from the default branch.
  `tfpr apply -p <unit>` destroys it, merging without applying keeps it; a
  plain `tfpr apply` never destroys a removed unit.
- tfpr v12.3.0 to v12.3.1 in all five callers: report headings count imports
  (`1 to import, 0 to add, ...`), and the removed-unit comment and merge-gate
  title say the pull request destroys nothing instead of claiming resources
  keep running.
- `management-resources`: `Azure/avm-ptn-alz-management/azurerm` 0.9.0 to 0.10.0,
  matching the reference environment. 0.10.0 raises the azapi minimum to
  `~> 2.12`, which `root.hcl` already requires; telemetry stays off, so its
  new deployment permission does not apply. No other input or output change.
- `examples/connectivity/hub-spoke-minimal` and `hub-spoke-firewall`:
  `Azure/avm-ptn-alz-connectivity-hub-and-spoke-vnet/azurerm` 0.17.7 to 0.18.1,
  matching the reference environment. 0.18.0 stops imported subnets and peerings
  from dropping out of plans. 0.18.1 adds private-only Bastion; both examples
  keep Bastion off, so its state migration does not apply.
- checkov 3.3.8 to 3.4.0 in `mise.toml`, matching the runner image 2.1.0. No
  caller or unit change.
- The engine callers move to tfpr v12.3.0. Each release now carries an SPDX
  software bill of materials for the tfpr binaries, `tfpr.spdx.json`, with a
  keyless signature in `tfpr.spdx.json.bundle`. No caller change.
- The engine callers move to tfpr v12.2.0. Releases now also trust the
  license portal's standby signing key, so a later rotation of the license
  signing key needs no engine bump. No caller change.
- The engine callers move to tfpr v12.1.1. Plan reports, drift issues and the
  job log now redact credential-like values that Terraform does not mark
  sensitive (connection strings, instrumentation and access keys, secrets,
  passwords, tokens, SAS), and the public entrypoint ships a security policy.
  No caller change.
