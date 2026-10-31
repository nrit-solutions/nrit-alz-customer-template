# Changelog

Changes to this repository: version bumps (AVM modules, the ALZ and AMBA
library refs, the engine caller pins), new units, and new workloads.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

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
